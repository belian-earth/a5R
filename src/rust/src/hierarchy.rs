use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::threading::{map_cells, raw_to_u64, u64_to_raw, u64s_to_list};

/// Get the resolution of A5 cell indices.
///
/// @param cell List of raw(8) cell ID blobs.
/// @return Integer vector of resolutions.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_resolution_rs(cell: List) -> Integers {
    let results = map_cells(&cell, |id| Some(a5::get_resolution(id)));

    let n = cell.len();
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
/// @param cell List of raw(8) cell ID blobs.
/// @param parent_resolution Integer: target parent resolution. NULL for
///   immediate parent.
/// @return List of raw(8) parent cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_parent_rs(cell: List, parent_resolution: Nullable<i32>) -> List {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };

    let results = map_cells(&cell, |id| {
        a5::cell_to_parent(id, pres).ok()
    });

    u64s_to_list(results)
}

/// Get child cells.
///
/// @param cell A single raw(8) cell ID blob.
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @return List of raw(8) child cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(cell: Robj, child_resolution: Nullable<i32>) -> List {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let id = match raw_to_u64(&cell) {
        Some(id) => id,
        None => throw_r_error("invalid cell ID: NULL or wrong size"),
    };
    match a5::cell_to_children(id, cres) {
        Ok(children) => {
            let values: Vec<Robj> = children.iter().map(|c| u64_to_raw(*c)).collect();
            List::from_values(values)
        }
        Err(e) => throw_r_error(format!("cell_to_children failed: {}", e)),
    }
}

/// Get all 12 resolution-0 root cells.
///
/// @return List of 12 raw(8) cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_res0_cells_rs() -> List {
    match a5::get_res0_cells() {
        Ok(cells) => {
            let values: Vec<Robj> = cells.iter().map(|c| u64_to_raw(*c)).collect();
            List::from_values(values)
        }
        Err(e) => throw_r_error(format!("get_res0_cells failed: {}", e)),
    }
}

/// Compact a set of A5 cell IDs.
///
/// @param cells List of raw(8) cell ID blobs.
/// @return List of raw(8) compacted cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(cells: List) -> List {
    let ids: Vec<u64> = (0..cells.len())
        .filter_map(|i| {
            let robj = cells.elt(i).unwrap_or_default();
            raw_to_u64(&robj)
        })
        .collect();
    match a5::compact(&ids) {
        Ok(compacted) => {
            let values: Vec<Robj> = compacted.iter().map(|c| u64_to_raw(*c)).collect();
            List::from_values(values)
        }
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param cells List of raw(8) cell ID blobs.
/// @param target_resolution Integer: the resolution to expand to.
/// @return List of raw(8) uncompacted cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(cells: List, target_resolution: i32) -> List {
    let ids: Vec<u64> = (0..cells.len())
        .filter_map(|i| {
            let robj = cells.elt(i).unwrap_or_default();
            raw_to_u64(&robj)
        })
        .collect();
    match a5::uncompact(&ids, target_resolution) {
        Ok(result) => {
            let values: Vec<Robj> = result.iter().map(|c| u64_to_raw(*c)).collect();
            List::from_values(values)
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
