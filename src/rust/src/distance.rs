use extendr_api::prelude::*;
use geographiclib_rs::{Geodesic, InverseGeodesic};

use crate::cell_raw::map_cell_pairs;

/// Mean radius of the GRS80 ellipsoid (metres). Matches the constant the
/// `geo` crate uses for spherical (haversine / rhumb) measurements, so
/// results are unchanged from earlier versions.
const EARTH_RADIUS_M: f64 = 6_371_008.8;

/// Great-circle distance on a sphere of radius [`EARTH_RADIUS_M`].
fn haversine(lon1: f64, lat1: f64, lon2: f64, lat2: f64) -> f64 {
    let theta1 = lat1.to_radians();
    let theta2 = lat2.to_radians();
    let delta_theta = (lat2 - lat1).to_radians();
    let delta_lambda = (lon2 - lon1).to_radians();
    let a = (delta_theta / 2.0).sin().powi(2)
        + theta1.cos() * theta2.cos() * (delta_lambda / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();
    EARTH_RADIUS_M * c
}

/// Loxodrome (constant-bearing) distance on a sphere of radius
/// [`EARTH_RADIUS_M`]. Port of the `geo` crate's rhumb calculation,
/// including the shorter-path choice across the antimeridian.
fn rhumb(lon1: f64, lat1: f64, lon2: f64, lat2: f64) -> f64 {
    use std::f64::consts::PI;
    let phi1 = lat1.to_radians();
    let phi2 = lat2.to_radians();
    let mut delta_lambda = (lon2 - lon1).to_radians();
    if delta_lambda > PI {
        delta_lambda -= 2.0 * PI;
    }
    if delta_lambda < -PI {
        delta_lambda += 2.0 * PI;
    }
    let delta_psi = ((phi2 / 2.0 + PI / 4.0).tan() / (phi1 / 2.0 + PI / 4.0).tan()).ln();
    let delta_phi = phi2 - phi1;
    // Guard the q ratio against a vanishing delta_psi (east-west lines).
    let q = if delta_psi.abs() > 1.0e-11 {
        delta_phi / delta_psi
    } else {
        phi1.cos()
    };
    let delta = (delta_phi * delta_phi + q * q * delta_lambda * delta_lambda).sqrt();
    delta * EARTH_RADIUS_M
}

/// Distance between two cell centroids using the specified method.
fn cell_distance(from: u64, to: u64, method: &str, geod: &Geodesic) -> Option<f64> {
    let from_ll = a5::cell_to_lonlat(from).ok()?;
    let to_ll = a5::cell_to_lonlat(to).ok()?;
    let (lon1, lat1) = (from_ll.longitude(), from_ll.latitude());
    let (lon2, lat2) = (to_ll.longitude(), to_ll.latitude());
    Some(match method {
        "geodesic" => geod.inverse(lat1, lon1, lat2, lon2),
        "rhumb" => rhumb(lon1, lat1, lon2, lat2),
        _ => haversine(lon1, lat1, lon2, lat2),
    })
}

/// Distance between pairs of cell centroids.
///
/// @param from_cells List with b1..b8 raw vectors for `from` cells.
/// @param to_cells List with b1..b8 raw vectors for `to` cells.
/// @param method Distance method: "haversine", "geodesic", or "rhumb".
/// @return Numeric vector of distances in metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_distance_rs(from_cells: List, to_cells: List, method: &str) -> Doubles {
    // WGS84 geoid for geodesic measurements; built once per call.
    let geod = Geodesic::wgs84();
    let results = map_cell_pairs(&from_cells, &to_cells, |f, t| {
        cell_distance(f, t, method, &geod)
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
