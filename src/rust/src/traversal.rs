use extendr_api::prelude::*;

use crate::covering::cells_to_coverings;

/// Get all cells within k hops of each centre cell, through shared edges.
///
/// @param cells List with b1..b8 raw vectors.
/// @param k Number of hops.
/// @return A list of coverings, one per cell (NULL for an NA cell).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_rs(cells: List, k: i32) -> List {
    let k = k as usize;
    cells_to_coverings(&cells, "grid_disk", |id| a5::grid_disk(id, k))
}

/// Get all cells within k hops of each centre cell, through shared vertices.
///
/// @param cells List with b1..b8 raw vectors.
/// @param k Number of hops.
/// @return A list of coverings, one per cell (NULL for an NA cell).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_vertex_rs(cells: List, k: i32) -> List {
    let k = k as usize;
    cells_to_coverings(&cells, "grid_disk_vertex", |id| a5::grid_disk_vertex(id, k))
}

/// Get all cells within a great-circle radius of each centre cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param radius Radius in metres.
/// @return A list of coverings, one per cell (NULL for an NA cell).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_spherical_cap_rs(cells: List, radius: f64) -> List {
    cells_to_coverings(&cells, "spherical_cap", |id| a5::spherical_cap(id, radius))
}

extendr_module! {
    mod traversal;
    fn a5_grid_disk_rs;
    fn a5_grid_disk_vertex_rs;
    fn a5_spherical_cap_rs;
}
