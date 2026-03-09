use extendr_api::prelude::*;

use crate::hilo::{hilo_to_u64, u64s_to_hilo_list};

/// Get all cells within k hops of a centre cell.
///
/// @param hi,lo Scalar doubles (hi/lo u32 halves of a single cell ID).
/// @param k Number of hops.
/// @param vertex If TRUE, include vertex-sharing (8-connected) neighbours.
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_rs(hi: f64, lo: f64, k: i32, vertex: bool) -> List {
    match hilo_to_u64(hi, lo) {
        Some(id) => {
            let result = if vertex {
                a5::grid_disk_vertex(id, k as usize)
            } else {
                a5::grid_disk(id, k as usize)
            };
            match result {
                Ok(cells) => {
                    let results: Vec<Option<u64>> =
                        cells.into_iter().map(|c| Some(c)).collect();
                    u64s_to_hilo_list(results)
                }
                Err(e) => throw_r_error(format!("grid_disk failed: {}", e)),
            }
        }
        None => throw_r_error("invalid cell: NA"),
    }
}

/// Get all cells within a great-circle radius of a centre cell.
///
/// @param hi,lo Scalar doubles (hi/lo u32 halves of a single cell ID).
/// @param radius Great-circle radius in metres.
/// @return List with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_spherical_cap_rs(hi: f64, lo: f64, radius: f64) -> List {
    match hilo_to_u64(hi, lo) {
        Some(id) => match a5::spherical_cap(id, radius) {
            Ok(cells) => {
                let results: Vec<Option<u64>> =
                    cells.into_iter().map(|c| Some(c)).collect();
                u64s_to_hilo_list(results)
            }
            Err(e) => throw_r_error(format!("spherical_cap failed: {}", e)),
        },
        None => throw_r_error("invalid cell: NA"),
    }
}

extendr_module! {
    mod traversal;
    fn a5_grid_disk_rs;
    fn a5_spherical_cap_rs;
}
