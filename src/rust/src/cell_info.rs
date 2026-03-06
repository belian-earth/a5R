use extendr_api::prelude::*;

use crate::threading::raw_to_u64;

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

/// Validate cell ID blobs.
///
/// @param cell List of raw(8) cell ID blobs.
/// @return Logical vector indicating validity.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_cell_rs(cell: List) -> Logicals {
    let n = cell.len();
    let mut out = Logicals::new(n);
    for i in 0..n {
        let robj = cell.elt(i).unwrap_or_default();
        if robj.is_null() {
            out.set_elt(i, Rbool::na());
        } else {
            out.set_elt(i, Rbool::from(raw_to_u64(&robj).is_some()));
        }
    }
    out
}

/// Validate hex cell ID strings (for use before conversion to blob).
///
/// @param cell Character vector of hex strings to validate.
/// @return Logical vector indicating validity.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_hex_rs(cell: Strings) -> Logicals {
    let n = cell.len();
    let mut out = Logicals::new(n);
    for i in 0..n {
        let s = &cell[i];
        if s.is_na() {
            out.set_elt(i, Rbool::na());
        } else {
            out.set_elt(i, Rbool::from(a5::hex_to_u64(s.as_str()).is_ok()));
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
    fn a5_is_valid_hex_rs;
}
