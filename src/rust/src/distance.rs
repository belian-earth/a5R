use extendr_api::prelude::*;
use geo::{Distance, Geodesic, Haversine, Point, Rhumb};

use crate::threading::map_cell_pairs;

/// Distance between two cell centroids using the specified method.
///
/// Uses `cell_to_lonlat` (which applies the authalic→geodetic latitude
/// correction) rather than raw spherical coordinates, so results match
/// sf/s2.
fn cell_distance(from: &str, to: &str, method: &str) -> Option<f64> {
    let from_ll = a5::cell_to_lonlat(a5::hex_to_u64(from).ok()?).ok()?;
    let to_ll = a5::cell_to_lonlat(a5::hex_to_u64(to).ok()?).ok()?;
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
/// @param from Character vector of hex-encoded cell IDs.
/// @param to Character vector of hex-encoded cell IDs (same length).
/// @param method Distance method: "haversine", "geodesic", or "rhumb".
/// @return Numeric vector of distances in metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_distance_rs(from: Strings, to: Strings, method: &str) -> Doubles {
    let results = map_cell_pairs(&from, &to, |f, t| cell_distance(f, t, method));

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
