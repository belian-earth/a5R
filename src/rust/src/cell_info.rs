use extendr_api::prelude::*;

use crate::threading::map_cells;

/// Get the area (in square metres) of cells at a given resolution.
///
/// @param resolution Integer vector of resolutions (0--30).
/// @return Numeric vector of areas in square metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_area_rs(resolution: Integers) -> Doubles {
    let n = resolution.len();
    let mut out = Doubles::new(n);
    for i in 0..n {
        let r = resolution[i];
        if r.is_na() {
            out.set_elt(i, Rfloat::na());
        } else {
            out.set_elt(i, Rfloat::from(a5::cell_area(r.inner())));
        }
    }
    out
}

/// Get total number of cells at a given resolution.
///
/// @param resolution Integer scalar (0--30).
/// @return Numeric scalar (as double, since R has no u64).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_num_cells_rs(resolution: i32) -> f64 {
    a5::get_num_cells(resolution) as f64
}

/// Number of children per parent cell between two resolutions.
///
/// @param parent_resolution Integer scalar.
/// @param child_resolution Integer scalar.
/// @return Numeric scalar (as double).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_num_children_rs(parent_resolution: i32, child_resolution: i32) -> f64 {
    a5::get_num_children(parent_resolution, child_resolution) as f64
}

/// Validate hex cell IDs.
///
/// @param cell Character vector of hex strings to validate.
/// @return Logical vector indicating validity.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_cell_rs(cell: Strings) -> Logicals {
    let results = map_cells(&cell, |s| Some(a5::hex_to_u64(s).is_ok()));

    let n = cell.len();
    let mut out = Logicals::new(n);
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(v) => out.set_elt(i, Rbool::from(v)),
            None => out.set_elt(i, Rbool::na()),
        }
    }
    out
}

extendr_module! {
    mod cell_info;
    fn a5_cell_area_rs;
    fn a5_get_num_cells_rs;
    fn a5_get_num_children_rs;
    fn a5_is_valid_cell_rs;
}
