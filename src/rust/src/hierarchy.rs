use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::threading::map_cells;

/// Get the resolution of A5 cell indices.
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @return Integer vector of resolutions.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_resolution_rs(cell: Strings) -> Integers {
    let results = map_cells(&cell, |s| {
        let id = a5::hex_to_u64(s).ok()?;
        Some(a5::get_resolution(id))
    });

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
/// @param cell Character vector of hex-encoded cell IDs.
/// @param parent_resolution Integer: target parent resolution. NULL for
///   immediate parent.
/// @return Character vector of hex-encoded parent cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_parent_rs(cell: Strings, parent_resolution: Nullable<i32>) -> Strings {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };

    let results = map_cells(&cell, |s| {
        let id = a5::hex_to_u64(s).ok()?;
        let parent = a5::cell_to_parent(id, pres).ok()?;
        Some(a5::u64_to_hex(parent))
    });

    let n = cell.len();
    let mut out = Strings::new(n);
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(s) => out.set_elt(i, Rstr::from(s)),
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Get child cells.
///
/// @param cell A single hex-encoded cell ID.
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @return Character vector of hex-encoded child cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(cell: &str, child_resolution: Nullable<i32>) -> Strings {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let id = match a5::hex_to_u64(cell) {
        Ok(id) => id,
        Err(e) => throw_r_error(format!("invalid cell ID: {}", e)),
    };
    match a5::cell_to_children(id, cres) {
        Ok(children) => children
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("cell_to_children failed: {}", e)),
    }
}

/// Get all 12 resolution-0 root cells.
///
/// @return Character vector of 12 hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_res0_cells_rs() -> Strings {
    match a5::get_res0_cells() {
        Ok(cells) => cells
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("get_res0_cells failed: {}", e)),
    }
}

/// Compact a set of A5 cell IDs.
///
/// Merges sibling groups into their common parent.
///
/// @param cells Character vector of hex-encoded cell IDs.
/// @return Character vector of compacted hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(cells: Strings) -> Strings {
    let ids: Vec<u64> = cells
        .iter()
        .filter(|s| !s.is_na())
        .filter_map(|s| a5::hex_to_u64(s.as_str()).ok())
        .collect();
    match a5::compact(&ids) {
        Ok(compacted) => compacted
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param cells Character vector of hex-encoded cell IDs.
/// @param target_resolution Integer: the resolution to expand to.
/// @return Character vector of uncompacted hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(cells: Strings, target_resolution: i32) -> Strings {
    let ids: Vec<u64> = cells
        .iter()
        .filter(|s| !s.is_na())
        .filter_map(|s| a5::hex_to_u64(s.as_str()).ok())
        .collect();
    match a5::uncompact(&ids, target_resolution) {
        Ok(result) => result
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
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
