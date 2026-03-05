use extendr_api::prelude::*;

/// Get all cells within k hops of a centre cell.
///
/// @param cell A single hex-encoded cell ID.
/// @param k Number of hops.
/// @param vertex If TRUE, include vertex-sharing (8-connected) neighbours.
/// @return Character vector of hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_disk_rs(cell: &str, k: i32, vertex: bool) -> Strings {
    match a5::hex_to_u64(cell) {
        Ok(id) => {
            let result = if vertex {
                a5::grid_disk_vertex(id, k as usize)
            } else {
                a5::grid_disk(id, k as usize)
            };
            match result {
                Ok(cells) => cells
                    .iter()
                    .map(|c| Rstr::from(a5::u64_to_hex(*c)))
                    .collect::<Strings>(),
                Err(e) => throw_r_error(format!("grid_disk failed: {}", e)),
            }
        }
        Err(e) => throw_r_error(format!("invalid cell: {}", e)),
    }
}

/// Get all cells within a great-circle radius of a centre cell.
///
/// @param cell A single hex-encoded cell ID.
/// @param radius Great-circle radius in metres.
/// @return Character vector of hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_spherical_cap_rs(cell: &str, radius: f64) -> Strings {
    match a5::hex_to_u64(cell) {
        Ok(id) => match a5::spherical_cap(id, radius) {
            Ok(cells) => cells
                .iter()
                .map(|c| Rstr::from(a5::u64_to_hex(*c)))
                .collect::<Strings>(),
            Err(e) => throw_r_error(format!("spherical_cap failed: {}", e)),
        },
        Err(e) => throw_r_error(format!("invalid cell: {}", e)),
    }
}

extendr_module! {
    mod traversal;
    fn a5_grid_disk_rs;
    fn a5_spherical_cap_rs;
}
