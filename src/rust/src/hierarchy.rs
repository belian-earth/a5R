use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::cell_raw::{collect_ids, map_cells, scalar_cell_from_list, u64s_to_raw8_list};

/// Get the resolution of A5 cell indices.
///
/// @param cells List with b1..b8 raw vectors.
/// @return Integer vector of resolutions.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_resolution_rs(cells: List) -> Integers {
    let results = map_cells(&cells, |id| Some(a5::get_resolution(id)));

    let n = results.len();
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
/// @param cells List with b1..b8 raw vectors.
/// @param parent_resolution Integer: target parent resolution. NULL for
///   immediate parent.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_parent_rs(cells: List, parent_resolution: Nullable<i32>) -> List {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };

    let results = map_cells(&cells, |id| {
        a5::cell_to_parent(id, pres).ok()
    });

    u64s_to_raw8_list(results)
}

/// Get child cells.
///
/// @param cell List with b1..b8 raw vectors (length 1).
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(cell: List, child_resolution: Nullable<i32>) -> List {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let id = match scalar_cell_from_list(&cell) {
        Some(id) => id,
        None => throw_r_error("invalid cell ID: NA"),
    };
    match a5::cell_to_children(id, cres) {
        Ok(children) => {
            let results: Vec<Option<u64>> = children.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
        }
        Err(e) => throw_r_error(format!("cell_to_children failed: {}", e)),
    }
}

/// Get all 12 resolution-0 root cells.
///
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_res0_cells_rs() -> List {
    match a5::get_res0_cells() {
        Ok(cells) => {
            let results: Vec<Option<u64>> = cells.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
        }
        Err(e) => throw_r_error(format!("get_res0_cells failed: {}", e)),
    }
}

/// Compact a set of A5 cell IDs.
///
/// @param cells List with b1..b8 raw vectors.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(cells: List) -> List {
    let ids = collect_ids(&cells);
    match a5::compact(&ids) {
        Ok(compacted) => {
            let results: Vec<Option<u64>> = compacted.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
        }
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param cells List with b1..b8 raw vectors.
/// @param target_resolution Integer: the resolution to expand to.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(cells: List, target_resolution: i32) -> List {
    let ids = collect_ids(&cells);
    match a5::uncompact(&ids, target_resolution) {
        Ok(result) => {
            let results: Vec<Option<u64>> = result.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
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
