use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::hilo::{hilo_to_u64, map_cells, u64s_to_hilo_list};

/// Get the resolution of A5 cell indices.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @return Integer vector of resolutions.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_resolution_rs(hi: Doubles, lo: Doubles) -> Integers {
    let results = map_cells(&hi, &lo, |id| Some(a5::get_resolution(id)));

    let n = hi.len();
    let mut out = Integers::new(n);
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(v) => out.set_elt(i, Rint::from(v)),
            None => out.set_elt(i, Rint::na()),
        }
    }
    out
}

/// Navigate to parent cell(s).
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @param parent_resolution Integer: target parent resolution. NULL for
///   immediate parent.
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_parent_rs(hi: Doubles, lo: Doubles, parent_resolution: Nullable<i32>) -> List {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };

    let results = map_cells(&hi, &lo, |id| {
        a5::cell_to_parent(id, pres).ok()
    });

    u64s_to_hilo_list(results)
}

/// Get child cells.
///
/// @param hi,lo Scalar doubles (hi/lo u32 halves of a single cell ID).
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(hi: f64, lo: f64, child_resolution: Nullable<i32>) -> List {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let id = match hilo_to_u64(hi, lo) {
        Some(id) => id,
        None => throw_r_error("invalid cell ID: NA"),
    };
    match a5::cell_to_children(id, cres) {
        Ok(children) => {
            let results: Vec<Option<u64>> = children.into_iter().map(|c| Some(c)).collect();
            u64s_to_hilo_list(results)
        }
        Err(e) => throw_r_error(format!("cell_to_children failed: {}", e)),
    }
}

/// Get all 12 resolution-0 root cells.
///
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_res0_cells_rs() -> List {
    match a5::get_res0_cells() {
        Ok(cells) => {
            let results: Vec<Option<u64>> = cells.into_iter().map(|c| Some(c)).collect();
            u64s_to_hilo_list(results)
        }
        Err(e) => throw_r_error(format!("get_res0_cells failed: {}", e)),
    }
}

/// Compact a set of A5 cell IDs.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(hi: Doubles, lo: Doubles) -> List {
    let ids: Vec<u64> = (0..hi.len())
        .filter_map(|i| hilo_to_u64(hi[i].inner(), lo[i].inner()))
        .collect();
    match a5::compact(&ids) {
        Ok(compacted) => {
            let results: Vec<Option<u64>> = compacted.into_iter().map(|c| Some(c)).collect();
            u64s_to_hilo_list(results)
        }
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @param target_resolution Integer: the resolution to expand to.
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(hi: Doubles, lo: Doubles, target_resolution: i32) -> List {
    let ids: Vec<u64> = (0..hi.len())
        .filter_map(|i| hilo_to_u64(hi[i].inner(), lo[i].inner()))
        .collect();
    match a5::uncompact(&ids, target_resolution) {
        Ok(result) => {
            let results: Vec<Option<u64>> = result.into_iter().map(|c| Some(c)).collect();
            u64s_to_hilo_list(results)
        }
        Err(e) => throw_r_error(format!("uncompact failed: {}", e)),
    }
}

extendr_module! {
    mod hierarchy;
    fn a5_get_resolution_rs;
    fn a5_cell_to_parent_rs;
    fn a5_cell_to_children_rs;
    fn a5_get_res0_cells_rs;
    fn a5_compact_rs;
    fn a5_uncompact_rs;
}
