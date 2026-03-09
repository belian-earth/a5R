use extendr_api::prelude::*;

use crate::hilo::hilo_to_u64;

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

/// Validate cell IDs stored as hi/lo doubles.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @return Logical vector indicating validity.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_cell_rs(hi: Doubles, lo: Doubles) -> Logicals {
    let n = hi.len();
    let mut out = Logicals::new(n);
    for i in 0..n {
        let h = hi[i];
        let l = lo[i];
        if h.is_na() || l.is_na() {
            out.set_elt(i, Rbool::na());
        } else {
            out.set_elt(i, Rbool::from(hilo_to_u64(h.inner(), l.inner()).is_some()));
        }
    }
    out
}

/// Validate hex cell ID strings (for use before conversion to rcrd).
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
