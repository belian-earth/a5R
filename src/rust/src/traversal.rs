use extendr_api::prelude::*;

use crate::cell_raw::one_to_many;

/// Get all cells within k hops of each centre cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param k Number of hops.
/// @param vertex If TRUE, include vertex-sharing (8-connected) neighbours.
/// @param simplify If TRUE one flat b1..b8 list, else a list of a5_cell
///   objects, one per input.
/// @return See simplify.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_rs(cells: List, k: i32, vertex: bool, simplify: bool) -> Robj {
    let k = k as usize;
    one_to_many(&cells, "grid_disk", simplify, |id| {
        if vertex {
            a5::grid_disk_vertex(id, k)
        } else {
            a5::grid_disk(id, k)
        }
    })
}

/// Get all cells within a great-circle radius of each centre cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param radius Radius in metres.
/// @param simplify If TRUE one flat b1..b8 list, else a list of a5_cell
///   objects, one per input.
/// @return See simplify.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_spherical_cap_rs(cells: List, radius: f64, simplify: bool) -> Robj {
    one_to_many(&cells, "spherical_cap", simplify, |id| a5::spherical_cap(id, radius))
}

extendr_module! {
    mod traversal;
    fn a5_grid_disk_rs;
    fn a5_spherical_cap_rs;
}
