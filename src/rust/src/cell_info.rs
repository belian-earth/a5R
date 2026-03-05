use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::threading::{get_num_threads, maybe_par};

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

/// Validate hex cell IDs.
///
/// @param cell Character vector of hex strings to validate.
/// @return Logical vector indicating validity.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_cell_rs(cell: Strings) -> Logicals {
    let n = cell.len();

    if get_num_threads() <= 1 {
        let mut out = Logicals::new(n);
        for i in 0..n {
            let s = &cell[i];
            if s.is_na() {
                out.set_elt(i, Rbool::na());
                continue;
            }
            let valid = a5::hex_to_u64(s.as_str()).is_ok();
            out.set_elt(i, Rbool::from(valid));
        }
        out
    } else {
        let inputs: Vec<Option<&str>> = (0..n)
            .map(|i| {
                let s = &cell[i];
                if s.is_na() { None } else { Some(s.as_str()) }
            })
            .collect();

        let results: Vec<Option<bool>> = maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt_s| {
                    let s = (*opt_s)?;
                    Some(a5::hex_to_u64(s).is_ok())
                })
                .collect()
        });

        let mut out = Logicals::new(n);
        for (i, r) in results.into_iter().enumerate() {
            match r {
                Some(v) => out.set_elt(i, Rbool::from(v)),
                None => out.set_elt(i, Rbool::na()),
            }
        }
        out
    }
}

extendr_module! {
    mod cell_info;
    fn a5_cell_area_rs;
    fn a5_get_num_cells_rs;
    fn a5_is_valid_cell_rs;
}
