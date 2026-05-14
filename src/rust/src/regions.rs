use extendr_api::prelude::*;
use rayon::prelude::*;
use std::collections::HashSet;
use std::result::Result as StdResult;

use crate::cell_raw::u64s_to_raw8_list;
use crate::threading::{get_num_threads, maybe_par};

/// Build per-ring `Vec<a5::LonLat>`s from flat coordinate slices and offsets.
fn split_rings(lon: &Doubles, lat: &Doubles, offsets: &Integers) -> Vec<Vec<a5::LonLat>> {
    let n_rings = offsets.len().saturating_sub(1);
    let mut out: Vec<Vec<a5::LonLat>> = Vec::with_capacity(n_rings);
    for i in 0..n_rings {
        let start = offsets[i].inner() as usize;
        let end = offsets[i + 1].inner() as usize;
        let mut ring: Vec<a5::LonLat> = Vec::with_capacity(end.saturating_sub(start));
        for j in start..end {
            ring.push(a5::LonLat::new(lon[j].inner(), lat[j].inner()));
        }
        out.push(ring);
    }
    out
}

/// Per-part processing: outer cells minus union of hole cells, all at `resolution`.
fn process_part(
    p: i32,
    rings: &[Vec<a5::LonLat>],
    part_id: &[i32],
    is_outer: &[i32],
    resolution: i32,
) -> StdResult<Vec<u64>, String> {
    let mut outer_ring_idx: Option<usize> = None;
    let mut hole_ring_indices: Vec<usize> = Vec::new();
    for (i, &pid) in part_id.iter().enumerate() {
        if pid != p {
            continue;
        }
        if is_outer[i] != 0 {
            outer_ring_idx = Some(i);
        } else {
            hole_ring_indices.push(i);
        }
    }
    let oi = match outer_ring_idx {
        Some(i) => i,
        None => return Ok(Vec::new()),
    };

    let outer_compacted = a5::polygon_to_cells(&rings[oi], resolution)?;
    let outer_uncompacted = a5::uncompact(&outer_compacted, resolution)?;
    let mut cells: HashSet<u64> = outer_uncompacted.into_iter().collect();

    for &hi in &hole_ring_indices {
        let hole_compacted = a5::polygon_to_cells(&rings[hi], resolution)?;
        let hole_uncompacted = a5::uncompact(&hole_compacted, resolution)?;
        for h in hole_uncompacted {
            cells.remove(&h);
        }
    }

    Ok(cells.into_iter().collect())
}

/// Convert one or more polygon parts (with optional holes) to A5 cells.
///
/// `lon`, `lat` are flat coordinate vectors; `offsets` is cumulative
/// (length `n_rings + 1`) so ring `i` is `lon[offsets[i]..offsets[i+1]]`.
/// `part_id` (length `n_rings`) groups rings by polygon part. `is_outer`
/// (length `n_rings`, 1 = outer / 0 = hole) classifies each ring.
///
/// For each polygon part, the outer ring is converted to cells, the
/// uncompacted cells inside any hole rings are subtracted, and the
/// remaining cells are unioned across parts. The result is recompacted
/// at the end. A single-outer-no-holes input takes a fast path that
/// passes the upstream compacted result through unchanged.
///
/// @noRd
/// @keywords internal
#[extendr]
fn a5_polygon_to_cells_rs(
    lon: Doubles,
    lat: Doubles,
    offsets: Integers,
    part_id: Integers,
    is_outer: Integers,
    resolution: i32,
) -> List {
    let rings = split_rings(&lon, &lat, &offsets);
    let n_rings = rings.len();

    if n_rings == 0 {
        return u64s_to_raw8_list(vec![]);
    }

    let part_id_vec: Vec<i32> = part_id.iter().map(|p| p.inner()).collect();
    let is_outer_vec: Vec<i32> = is_outer.iter().map(|b| b.inner()).collect();

    let max_part = part_id_vec.iter().copied().max().unwrap_or(0);
    if max_part <= 0 {
        return u64s_to_raw8_list(vec![]);
    }

    // Fast path: a single outer ring with no holes (the common case for
    // matrix / data.frame input and for an `sfc` of one POLYGON).
    let total_outer = is_outer_vec.iter().filter(|&&v| v != 0).count();
    if max_part == 1 && n_rings == 1 && total_outer == 1 {
        return match a5::polygon_to_cells(&rings[0], resolution) {
            Ok(cells) => {
                let out: Vec<Option<u64>> = cells.into_iter().map(Some).collect();
                u64s_to_raw8_list(out)
            }
            Err(e) => throw_r_error(format!("polygon_to_cells failed: {}", e)),
        };
    }

    let parts: Vec<i32> = (1..=max_part).collect();
    let per_part: Vec<StdResult<Vec<u64>, String>> = if get_num_threads() <= 1 {
        parts
            .iter()
            .map(|&p| process_part(p, &rings, &part_id_vec, &is_outer_vec, resolution))
            .collect()
    } else {
        maybe_par(|| {
            parts
                .par_iter()
                .map(|&p| process_part(p, &rings, &part_id_vec, &is_outer_vec, resolution))
                .collect()
        })
    };

    let mut union: HashSet<u64> = HashSet::new();
    for r in per_part {
        let part_cells = match r {
            Ok(c) => c,
            Err(e) => throw_r_error(format!("polygon_to_cells failed: {}", e)),
        };
        union.extend(part_cells);
    }

    let mut combined: Vec<u64> = union.into_iter().collect();
    combined.sort_unstable();
    let recompacted = match a5::compact(&combined) {
        Ok(c) => c,
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    };

    let out: Vec<Option<u64>> = recompacted.into_iter().map(Some).collect();
    u64s_to_raw8_list(out)
}

/// Convert one or more linestring waypoint sequences to A5 cells.
///
/// Per-feature `line_string_to_cells` results are concatenated in feature
/// order with first-seen deduplication, preserving discovery order along
/// the path.
///
/// @noRd
/// @keywords internal
#[extendr]
fn a5_linestring_to_cells_rs(
    lon: Doubles,
    lat: Doubles,
    offsets: Integers,
    resolution: i32,
) -> List {
    let features = split_rings(&lon, &lat, &offsets);

    if features.is_empty() {
        return u64s_to_raw8_list(vec![]);
    }

    let per_feature: Vec<StdResult<Vec<u64>, String>> =
        if get_num_threads() <= 1 || features.len() == 1 {
            features
                .iter()
                .map(|w| a5::line_string_to_cells(w, resolution))
                .collect()
        } else {
            maybe_par(|| {
                features
                    .par_iter()
                    .map(|w| a5::line_string_to_cells(w, resolution))
                    .collect()
            })
        };

    let mut seen: HashSet<u64> = HashSet::new();
    let mut result: Vec<u64> = Vec::new();
    for r in per_feature {
        let cells = match r {
            Ok(c) => c,
            Err(e) => throw_r_error(format!("line_string_to_cells failed: {}", e)),
        };
        for c in cells {
            if seen.insert(c) {
                result.push(c);
            }
        }
    }

    let out: Vec<Option<u64>> = result.into_iter().map(Some).collect();
    u64s_to_raw8_list(out)
}

extendr_module! {
    mod regions;
    fn a5_polygon_to_cells_rs;
    fn a5_linestring_to_cells_rs;
}
