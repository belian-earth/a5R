use extendr_api::prelude::*;
use geographiclib_rs::{Geodesic, InverseGeodesic};

use rayon::prelude::*;

use crate::cell_raw::{par_chunk, CellSlices, PAR_MIN};
use crate::threading::{get_num_threads, maybe_par};

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

/// A cell's centroid as (longitude, latitude), or None for NA or an invalid id.
fn centroid(cell: Option<u64>) -> Option<(f64, f64)> {
    let ll = a5::cell_to_lonlat(cell?).ok()?;
    Some((ll.longitude(), ll.latitude()))
}

/// Distance between pairs of cell centroids.
///
/// A side of length 1 is recycled here rather than in R, so its centroid is
/// computed once instead of once per pair.
///
/// @param from_cells List with b1..b8 raw vectors for `from` cells.
/// @param to_cells List with b1..b8 raw vectors for `to` cells.
/// @param n Output length: the common size of `from` and `to`.
/// @param method Distance method: "haversine", "geodesic", or "rhumb".
/// @return Numeric vector of distances in metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_distance_rs(from_cells: List, to_cells: List, n: i32, method: &str) -> Doubles {
    let n = n as usize;
    let from = CellSlices::from_list(&from_cells);
    let to = CellSlices::from_list(&to_cells);
    let fixed_from = (from.len == 1).then(|| centroid(from.get(0)));
    let fixed_to = (to.len == 1).then(|| centroid(to.get(0)));
    // WGS84 geoid for geodesic measurements; built once per call.
    let geod = Geodesic::wgs84();
    let measure: fn(f64, f64, f64, f64, &Geodesic) -> f64 = match method {
        "geodesic" => |lon1, lat1, lon2, lat2, g| g.inverse(lat1, lon1, lat2, lon2),
        "rhumb" => |lon1, lat1, lon2, lat2, _| rhumb(lon1, lat1, lon2, lat2),
        _ => |lon1, lat1, lon2, lat2, _| haversine(lon1, lat1, lon2, lat2),
    };
    let one = |i: usize| -> Rfloat {
        let a = fixed_from.unwrap_or_else(|| centroid(from.get(i)));
        let b = fixed_to.unwrap_or_else(|| centroid(to.get(i)));
        match (a, b) {
            (Some((lon1, lat1)), Some((lon2, lat2))) => measure(lon1, lat1, lon2, lat2, &geod).into(),
            _ => Rfloat::na(),
        }
    };

    let mut out = Doubles::new(n);
    {
        let d: &mut [Rfloat] = &mut out;
        if get_num_threads() <= 1 || n < PAR_MIN {
            for (i, x) in d.iter_mut().enumerate() {
                *x = one(i);
            }
        } else {
            let chunk = par_chunk(n);
            maybe_par(|| {
                d.par_chunks_mut(chunk).enumerate().for_each(|(c, part)| {
                    for (k, x) in part.iter_mut().enumerate() {
                        *x = one(c * chunk + k);
                    }
                })
            });
        }
    }
    out
}

extendr_module! {
    mod distance;
    fn a5_cell_distance_rs;
}
