use extendr_api::prelude::*;

use crate::threading::{raw_to_u64, u64_to_raw};

/// Get all cells within k hops of a centre cell.
///
/// @param cell A single raw(8) cell ID blob.
/// @param k Number of hops.
/// @param vertex If TRUE, include vertex-sharing (8-connected) neighbours.
/// @return List of raw(8) cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_rs(cell: Robj, k: i32, vertex: bool) -> List {
    match raw_to_u64(&cell) {
        Some(id) => {
            let result = if vertex {
                a5::grid_disk_vertex(id, k as usize)
            } else {
                a5::grid_disk(id, k as usize)
            };
            match result {
                Ok(cells) => {
                    let values: Vec<Robj> = cells.iter().map(|c| u64_to_raw(*c)).collect();
                    List::from_values(values)
                }
                Err(e) => throw_r_error(format!("grid_disk failed: {}", e)),
            }
        }
        None => throw_r_error("invalid cell: NULL or wrong size"),
    }
}

/// Get all cells within a great-circle radius of a centre cell.
///
/// @param cell A single raw(8) cell ID blob.
/// @param radius Great-circle radius in metres.
/// @return List of raw(8) cell ID blobs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_spherical_cap_rs(cell: Robj, radius: f64) -> List {
    match raw_to_u64(&cell) {
        Some(id) => match a5::spherical_cap(id, radius) {
            Ok(cells) => {
                let values: Vec<Robj> = cells.iter().map(|c| u64_to_raw(*c)).collect();
                List::from_values(values)
            }
            Err(e) => throw_r_error(format!("spherical_cap failed: {}", e)),
        },
        None => throw_r_error("invalid cell: NULL or wrong size"),
    }
}

extendr_module! {
    mod traversal;
    fn a5_grid_disk_rs;
    fn a5_spherical_cap_rs;
}
