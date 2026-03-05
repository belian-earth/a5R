use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::threading::{get_num_threads, maybe_par};

/// Convert longitude/latitude coordinates to A5 cell indices.
///
/// Vectorised over `lon`, `lat`, and `resolution`.
///
/// @param lon Numeric vector of longitudes (degrees).
/// @param lat Numeric vector of latitudes (degrees).
/// @param resolution Integer vector of resolutions (0--30).
/// @return A character vector of cell IDs (hex-encoded).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_lonlat_to_cell_rs(lon: Doubles, lat: Doubles, resolution: Integers) -> Strings {
    let n = lon.len();

    if get_num_threads() <= 1 {
        let mut out = Strings::new(n);
        for i in 0..n {
            let lo = lon[i];
            let la = lat[i];
            let res = resolution[i];
            if lo.is_na() || la.is_na() || res.is_na() {
                out.set_elt(i, Rstr::na());
                continue;
            }
            let lonlat = a5::LonLat::new(lo.inner(), la.inner());
            match a5::lonlat_to_cell(lonlat, res.inner()) {
                Ok(cell) => out.set_elt(i, Rstr::from(a5::u64_to_hex(cell))),
                Err(_) => out.set_elt(i, Rstr::na()),
            }
        }
        out
    } else {
        let inputs: Vec<(f64, f64, i32, bool)> = (0..n)
            .map(|i| {
                let lo = lon[i];
                let la = lat[i];
                let res = resolution[i];
                if lo.is_na() || la.is_na() || res.is_na() {
                    (0.0, 0.0, 0, true)
                } else {
                    (lo.inner(), la.inner(), res.inner(), false)
                }
            })
            .collect();

        let results: Vec<Option<String>> = maybe_par(|| {
            inputs
                .par_iter()
                .map(|&(lo, la, res, is_na)| {
                    if is_na {
                        return None;
                    }
                    let lonlat = a5::LonLat::new(lo, la);
                    a5::lonlat_to_cell(lonlat, res).ok().map(|c| a5::u64_to_hex(c))
                })
                .collect()
        });

        let mut out = Strings::new(n);
        for (i, r) in results.into_iter().enumerate() {
            match r {
                Some(s) => out.set_elt(i, Rstr::from(s)),
                None => out.set_elt(i, Rstr::na()),
            }
        }
        out
    }
}

/// Convert A5 cell indices to longitude/latitude coordinates.
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @param normalise Logical: if TRUE, wrap longitudes to the standard range.
/// @return A list with `lon` and `lat` numeric vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_lonlat_rs(cell: Strings, normalise: bool) -> List {
    let n = cell.len();

    if get_num_threads() <= 1 {
        let mut lon_out = Doubles::new(n);
        let mut lat_out = Doubles::new(n);
        for i in 0..n {
            let s = &cell[i];
            if s.is_na() {
                lon_out.set_elt(i, Rfloat::na());
                lat_out.set_elt(i, Rfloat::na());
                continue;
            }
            match a5::hex_to_u64(s.as_str()) {
                Ok(id) => match a5::cell_to_lonlat(id) {
                    Ok(ll) => {
                        let lon = if normalise {
                            ((ll.longitude() + 180.0) % 360.0 + 360.0) % 360.0 - 180.0
                        } else {
                            ll.longitude()
                        };
                        lon_out.set_elt(i, Rfloat::from(lon));
                        lat_out.set_elt(i, Rfloat::from(ll.latitude()));
                    }
                    Err(_) => {
                        lon_out.set_elt(i, Rfloat::na());
                        lat_out.set_elt(i, Rfloat::na());
                    }
                },
                Err(_) => {
                    lon_out.set_elt(i, Rfloat::na());
                    lat_out.set_elt(i, Rfloat::na());
                }
            }
        }
        list!(lon = lon_out, lat = lat_out)
    } else {
        let inputs: Vec<Option<&str>> = (0..n)
            .map(|i| {
                let s = &cell[i];
                if s.is_na() { None } else { Some(s.as_str()) }
            })
            .collect();

        let results: Vec<Option<(f64, f64)>> = maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt_s| {
                    let s = (*opt_s)?;
                    let id = a5::hex_to_u64(s).ok()?;
                    let ll = a5::cell_to_lonlat(id).ok()?;
                    let lon = if normalise {
                        ((ll.longitude() + 180.0) % 360.0 + 360.0) % 360.0 - 180.0
                    } else {
                        ll.longitude()
                    };
                    Some((lon, ll.latitude()))
                })
                .collect()
        });

        let mut lon_out = Doubles::new(n);
        let mut lat_out = Doubles::new(n);
        for (i, r) in results.into_iter().enumerate() {
            match r {
                Some((lon, lat)) => {
                    lon_out.set_elt(i, Rfloat::from(lon));
                    lat_out.set_elt(i, Rfloat::from(lat));
                }
                None => {
                    lon_out.set_elt(i, Rfloat::na());
                    lat_out.set_elt(i, Rfloat::na());
                }
            }
        }
        list!(lon = lon_out, lat = lat_out)
    }
}

extendr_module! {
    mod indexing;
    fn a5_lonlat_to_cell_rs;
    fn a5_cell_to_lonlat_rs;
}
