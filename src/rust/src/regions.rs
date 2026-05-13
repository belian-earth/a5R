use extendr_api::prelude::*;
use rayon::prelude::*;
use std::collections::HashSet;
use std::result::Result as StdResult;

use crate::cell_raw::u64s_to_raw8_list;
use crate::threading::{get_num_threads, maybe_par};

/// Convert a flat lon/lat/offsets bundle into per-feature `Vec<a5::LonLat>`s.
fn split_features(lon: &Doubles, lat: &Doubles, offsets: &Integers) -> Vec<Vec<a5::LonLat>> {
    let n_features = offsets.len().saturating_sub(1);
    let mut out: Vec<Vec<a5::LonLat>> = Vec::with_capacity(n_features);
    for i in 0..n_features {
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

/// Convert one or more polygon rings to A5 cells.
///
/// `lon`, `lat` are the flat coordinate vectors; `offsets` is cumulative
/// (length n_rings + 1). Single-ring inputs return the upstream compacted
/// result unchanged; multi-ring inputs uncompact each ring to `resolution`,
/// take the union, then compact once at the end.
///
/// @noRd
/// @keywords internal
#[extendr]
fn a5_polygon_to_cells_rs(lon: Doubles, lat: Doubles, offsets: Integers, resolution: i32) -> List {
    let features = split_features(&lon, &lat, &offsets);
    let n = features.len();

    if n == 0 {
        return u64s_to_raw8_list(vec![]);
    }

    if n == 1 {
        return match a5::polygon_to_cells(&features[0], resolution) {
            Ok(cells) => {
                let out: Vec<Option<u64>> = cells.into_iter().map(Some).collect();
                u64s_to_raw8_list(out)
            }
            Err(e) => throw_r_error(format!("polygon_to_cells failed: {}", e)),
        };
    }

    // Multi-ring: per-ring polygon_to_cells (parallel) → uncompact → union → compact.
    let per_ring: Vec<StdResult<Vec<u64>, String>> = if get_num_threads() <= 1 {
        features
            .iter()
            .map(|ring| a5::polygon_to_cells(ring, resolution))
            .collect()
    } else {
        maybe_par(|| {
            features
                .par_iter()
                .map(|ring| a5::polygon_to_cells(ring, resolution))
                .collect()
        })
    };

    let mut union: HashSet<u64> = HashSet::new();
    for r in per_ring {
        let compacted = match r {
            Ok(c) => c,
            Err(e) => throw_r_error(format!("polygon_to_cells failed: {}", e)),
        };
        match a5::uncompact(&compacted, resolution) {
            Ok(expanded) => union.extend(expanded),
            Err(e) => throw_r_error(format!("uncompact failed: {}", e)),
        }
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
    let features = split_features(&lon, &lat, &offsets);

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
