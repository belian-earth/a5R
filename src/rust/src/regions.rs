use extendr_api::prelude::*;
use rayon::prelude::*;
use std::collections::HashSet;
use std::result::Result as StdResult;

use a5::{Containment, PolygonToCellsOptions};

use crate::cell_raw::groups_to_robj;
use crate::covering::coverings_to_list;
use crate::threading::{get_num_threads, maybe_par};

/// Map the R-side containment string to the upstream option struct.
///
/// Accepts `"centre"` (cell centre inside the polygon; the default) or
/// `"overlapping"` (every cell touching the polygon, a superset of the
/// centre result). Any other value is an R error.
fn containment_options(containment: &str) -> PolygonToCellsOptions {
    let containment = match containment {
        "centre" => Containment::Center,
        "overlapping" => Containment::Overlapping,
        other => throw_r_error(format!(
            "unknown containment mode {:?}; expected \"centre\" or \"overlapping\"",
            other
        )),
    };
    PolygonToCellsOptions { containment }
}

/// Build per-ring `Vec<a5::LonLat>`s from flat coordinate slices and offsets.
pub(crate) fn split_rings(lon: &Doubles, lat: &Doubles, offsets: &Integers) -> Vec<Vec<a5::LonLat>> {
    let n_rings = offsets.len().saturating_sub(1);
    let mut out: Vec<Vec<a5::LonLat>> = Vec::with_capacity(n_rings);
    for i in 0..n_rings {
        let start = offsets[i].0 as usize;
        let end = offsets[i + 1].0 as usize;
        let mut ring: Vec<a5::LonLat> = Vec::with_capacity(end.saturating_sub(start));
        for j in start..end {
            ring.push(a5::LonLat::new(lon[j].0, lat[j].0));
        }
        out.push(ring);
    }
    out
}

/// Group rings into polygon parts as `[outer, holes...]`, in one pass.
///
/// `part_id` (1-based, one per ring) names each ring's part and `is_outer`
/// marks its outer ring. A part without an outer ring has no rings. The
/// ordering matches what `a5::polygon_to_cells` expects: index 0 is the
/// outer ring, the rest are holes.
pub(crate) fn group_parts(
    rings: Vec<Vec<a5::LonLat>>,
    part_id: &[i32],
    is_outer: &[i32],
    n_parts: usize,
) -> Vec<Vec<Vec<a5::LonLat>>> {
    let mut outers: Vec<Option<Vec<a5::LonLat>>> = vec![None; n_parts];
    let mut holes: Vec<Vec<Vec<a5::LonLat>>> = vec![Vec::new(); n_parts];
    for ((ring, &p), &outer) in rings.into_iter().zip(part_id).zip(is_outer) {
        let p = (p - 1) as usize;
        if outer != 0 {
            outers[p] = Some(ring);
        } else {
            holes[p].push(ring);
        }
    }
    outers
        .into_iter()
        .zip(holes)
        .map(|(outer, holes)| match outer {
            Some(outer) => std::iter::once(outer).chain(holes).collect(),
            None => Vec::new(),
        })
        .collect()
}

/// Convert polygon features (each one or more parts, with optional holes)
/// to coverings, one per feature.
///
/// `lon`, `lat` are flat coordinate vectors; `offsets` is cumulative
/// (length `n_rings + 1`) so ring `i` is `lon[offsets[i]..offsets[i+1]]`.
/// `part_id` (length `n_rings`, 1-based) groups rings by polygon part and
/// `is_outer` (length `n_rings`, 1 = outer / 0 = hole) classifies each ring.
/// `part_feature` (length `n_parts`, 1-based) names each part's feature.
/// `containment` is `"centre"` (cell centre inside the polygon) or
/// `"overlapping"` (any cell touching the polygon).
///
/// Each part goes to `a5::polygon_to_cells`, which excludes hole interiors
/// natively, in parallel across parts. A feature's parts are then merged
/// with `a5::union`, which works on the compacted cells directly. A feature
/// with no parts gets an empty covering at `resolution`.
///
/// @return A list of coverings, one per feature.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_polygon_to_cells_rs(
    lon: Doubles,
    lat: Doubles,
    offsets: Integers,
    part_id: Integers,
    is_outer: Integers,
    part_feature: Integers,
    n_features: i32,
    resolution: i32,
    containment: &str,
) -> List {
    let options = containment_options(containment);
    let part_id: Vec<i32> = part_id.iter().map(|p| p.0).collect();
    let is_outer: Vec<i32> = is_outer.iter().map(|b| b.0).collect();
    let part_feature: Vec<i32> = part_feature.iter().map(|f| f.0).collect();
    let parts = group_parts(
        split_rings(&lon, &lat, &offsets),
        &part_id,
        &is_outer,
        part_feature.len(),
    );

    let fill = |rings: &Vec<Vec<a5::LonLat>>| a5::polygon_to_cells(rings, resolution, Some(options));
    let per_part: Vec<StdResult<Vec<u64>, String>> = if get_num_threads() <= 1 || parts.len() == 1 {
        parts.iter().map(fill).collect()
    } else {
        maybe_par(|| parts.par_iter().map(fill).collect())
    };

    let mut features: Vec<Option<Vec<u64>>> = vec![None; n_features.max(0) as usize];
    for (r, &f) in per_part.into_iter().zip(&part_feature) {
        let covering = match r {
            Ok(c) => c,
            Err(e) => throw_r_error(format!("polygon_to_cells failed: {}", e)),
        };
        let slot = &mut features[(f - 1) as usize];
        *slot = Some(match slot.take() {
            None => covering,
            Some(acc) => match a5::union(&acc, &covering) {
                Ok(c) => c,
                Err(e) => throw_r_error(format!("union failed: {}", e)),
            },
        });
    }

    let results = features
        .into_iter()
        .map(|f| Some(f.map_or_else(|| a5::polygon_to_cells(&[], resolution, Some(options)), Ok)))
        .collect();
    coverings_to_list("polygon_to_cells", results)
}

/// Convert linestring features to A5 cells, one ordered path per feature.
///
/// `lon`, `lat`, `offsets` hold the lines as for polygons; `line_feature`
/// (length `n_lines`, 1-based) names each line's feature. Lines are traced
/// in parallel with `line_string_to_cells`; a feature's lines (the parts of
/// a `MULTILINESTRING`) are concatenated in order with first-seen
/// deduplication. A feature with no lines has no cells.
///
/// @param simplify If TRUE one flat b1..b8 list, the features' paths
///   concatenated (no deduplication across features); else a list of
///   a5_cell objects, one per feature.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_line_string_to_cells_rs(
    lon: Doubles,
    lat: Doubles,
    offsets: Integers,
    line_feature: Integers,
    n_features: i32,
    resolution: i32,
    simplify: bool,
) -> Robj {
    let lines = split_rings(&lon, &lat, &offsets);
    let line_feature: Vec<i32> = line_feature.iter().map(|f| f.0).collect();

    let trace = |w: &Vec<a5::LonLat>| a5::line_string_to_cells(w, resolution);
    let per_line: Vec<StdResult<Vec<u64>, String>> = if get_num_threads() <= 1 || lines.len() == 1 {
        lines.iter().map(trace).collect()
    } else {
        maybe_par(|| lines.par_iter().map(trace).collect())
    };

    let mut features: Vec<Vec<u64>> = vec![Vec::new(); n_features.max(0) as usize];
    let mut seen: Vec<HashSet<u64>> = vec![HashSet::new(); features.len()];
    for (r, &f) in per_line.into_iter().zip(&line_feature) {
        let cells = match r {
            Ok(c) => c,
            Err(e) => throw_r_error(format!("line_string_to_cells failed: {}", e)),
        };
        let f = (f - 1) as usize;
        for c in cells {
            if seen[f].insert(c) {
                features[f].push(c);
            }
        }
    }
    groups_to_robj(features, simplify)
}

extendr_module! {
    mod regions;
    fn a5_polygon_to_cells_rs;
    fn a5_line_string_to_cells_rs;
}
