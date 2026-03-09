use extendr_api::prelude::*;
use geo::{Distance, Geodesic, Haversine, Point, Rhumb};

use crate::hilo::map_cell_pairs;

/// Distance between two cell centroids using the specified method.
fn cell_distance(from: u64, to: u64, method: &str) -> Option<f64> {
    let from_ll = a5::cell_to_lonlat(from).ok()?;
    let to_ll = a5::cell_to_lonlat(to).ok()?;
    let p1 = Point::new(from_ll.longitude(), from_ll.latitude());
    let p2 = Point::new(to_ll.longitude(), to_ll.latitude());
    Some(match method {
        "geodesic" => Geodesic.distance(p1, p2),
        "rhumb" => Rhumb.distance(p1, p2),
        _ => Haversine.distance(p1, p2),
    })
}

/// Distance between pairs of cell centroids.
///
/// @param from_hi,from_lo Double vectors (hi/lo halves of `from` cell IDs).
/// @param to_hi,to_lo Double vectors (hi/lo halves of `to` cell IDs).
/// @param method Distance method: "haversine", "geodesic", or "rhumb".
/// @return Numeric vector of distances in metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_distance_rs(
    from_hi: Doubles,
    from_lo: Doubles,
    to_hi: Doubles,
    to_lo: Doubles,
    method: &str,
) -> Doubles {
    let results =
        map_cell_pairs(&from_hi, &from_lo, &to_hi, &to_lo, |f, t| {
            cell_distance(f, t, method)
        });

    let mut out = Doubles::new(results.len());
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(d) => out.set_elt(i, Rfloat::from(d)),
            None => out.set_elt(i, Rfloat::na()),
        }
    }
    out
}

extendr_module! {
    mod distance;
    fn a5_cell_distance_rs;
}
