use extendr_api::prelude::*;

use crate::cell_raw::one_to_many;

/// Get all cells within k hops of each centre cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param k Number of hops.
/// @param vertex If TRUE, include vertex-sharing (8-connected) neighbours.
/// @return list(cells = b1..b8 raw list, lengths = integer per input).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_rs(cells: List, k: i32, vertex: bool) -> List {
    let k = k as usize;
    one_to_many(&cells, "grid_disk", |id| {
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
/// @return list(cells = b1..b8 raw list, lengths = integer per input).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_spherical_cap_rs(cells: List, radius: f64) -> List {
    one_to_many(&cells, "spherical_cap", |id| a5::spherical_cap(id, radius))
}

extendr_module! {
    mod traversal;
    fn a5_grid_disk_rs;
    fn a5_spherical_cap_rs;
}
