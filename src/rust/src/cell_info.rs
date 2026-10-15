use extendr_api::prelude::*;

use crate::cell_raw::{map_cells, u64s_to_raw8_list, CellSlices};

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
            out.set_elt(i, Rfloat::from(a5::cell_area(r.0)));
        }
    }
    out
}

/// Get the average edge length (in metres) of cells at a given resolution.
///
/// Individual edge lengths vary from the average by roughly +/-10%
/// depending on the cell's shape and position on the globe.
///
/// @param resolution Integer vector of resolutions (0--30).
/// @return Numeric vector of average edge lengths in metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_edge_length_avg_rs(resolution: Integers) -> Doubles {
    let n = resolution.len();
    let mut out = Doubles::new(n);
    for i in 0..n {
        let r = resolution[i];
        if r.is_na() {
            out.set_elt(i, Rfloat::na());
        } else {
            out.set_elt(i, Rfloat::from(a5::cell_edge_length_avg(r.0)));
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

/// Validate cell IDs stored as raw bytes with upstream `is_valid_cell`.
///
/// @param cells List with b1..b8 raw vectors.
/// @return Logical vector: NA where the cell is NA.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_cell_rs(cells: List) -> Logicals {
    let cs = CellSlices::from_list(&cells);
    let n = cs.len;
    let mut out = Logicals::new(n);
    for i in 0..n {
        match cs.get(i) {
            Some(id) => out.set_elt(i, Rbool::from(a5::is_valid_cell(id))),
            None => out.set_elt(i, Rbool::na()),
        }
    }
    out
}

/// Validate hex cell ID strings: 16 hex digits encoding an A5 cell.
///
/// @param cell Character vector of hex strings to validate.
/// @return Logical vector: NA where the string is NA.
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
            let valid = s.len() == 16
                && a5::hex_to_u64(s.as_ref()).is_ok_and(a5::is_valid_cell);
            out.set_elt(i, Rbool::from(valid));
        }
    }
    out
}

/// Convert cell IDs from the v0 index (a5 crate <= 0.10) to v1.
///
/// @param cells List with b1..b8 raw vectors.
/// @return List with b1..b8 raw vectors. NA where the cell is NA; an error
///   naming the first cell that cannot be decoded.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_migrate_rs(cells: List) -> List {
    let results = map_cells(&cells, |id| Some(a5::migrate(id)));
    let mut out: Vec<Option<u64>> = Vec::with_capacity(results.len());
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(Ok(id)) => out.push(Some(id)),
            Some(Err(e)) => throw_r_error(format!("migrate failed for cell {}: {}", i + 1, e)),
            None => out.push(None),
        }
    }
    u64s_to_raw8_list(out)
}

/// Version of the bundled a5 crate, read from Cargo.lock at build time.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_crate_version_rs() -> &'static str {
    env!("A5_CRATE_VERSION")
}

extendr_module! {
    mod cell_info;
    fn a5_crate_version_rs;
    fn a5_cell_area_rs;
    fn a5_cell_edge_length_avg_rs;
    fn a5_get_num_cells_rs;
    fn a5_get_num_children_rs;
    fn a5_is_valid_cell_rs;
    fn a5_is_valid_hex_rs;
    fn a5_migrate_rs;
}
