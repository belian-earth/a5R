use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::hilo::{map_cells, u64s_to_hilo_list};
use crate::threading::{get_num_threads, maybe_par};

/// Convert longitude/latitude coordinates to A5 cell indices.
///
/// @param lon Numeric vector of longitudes (degrees).
/// @param lat Numeric vector of latitudes (degrees).
/// @param resolution Integer vector of resolutions (0--30).
/// @return A list with `hi` and `lo` double vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_lonlat_to_cell_rs(lon: Doubles, lat: Doubles, resolution: Integers) -> List {
    let n = lon.len();

    if get_num_threads() <= 1 {
        let results: Vec<Option<u64>> = (0..n)
            .map(|i| {
                let lo = lon[i];
                let la = lat[i];
                let res = resolution[i];
                if lo.is_na() || la.is_na() || res.is_na() {
                    None
                } else {
                    let lonlat = a5::LonLat::new(lo.inner(), la.inner());
                    a5::lonlat_to_cell(lonlat, res.inner()).ok()
                }
            })
            .collect();
        u64s_to_hilo_list(results)
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

        let results: Vec<Option<u64>> = maybe_par(|| {
            inputs
                .par_iter()
                .map(|&(lo, la, res, is_na)| {
                    if is_na {
                        return None;
                    }
                    let lonlat = a5::LonLat::new(lo, la);
                    a5::lonlat_to_cell(lonlat, res).ok()
                })
                .collect()
        });

        u64s_to_hilo_list(results)
    }
}

/// Convert A5 cell indices to longitude/latitude coordinates.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @param normalise Logical: if TRUE, wrap longitudes to the standard range.
/// @return A list with `lon` and `lat` numeric vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_lonlat_rs(hi: Doubles, lo: Doubles, normalise: bool) -> List {
    let results = map_cells(&hi, &lo, |id| {
        let ll = a5::cell_to_lonlat(id).ok()?;
        let lon = if normalise {
            ((ll.longitude() + 180.0) % 360.0 + 360.0) % 360.0 - 180.0
        } else {
            ll.longitude()
        };
        Some((lon, ll.latitude()))
    });

    let n = hi.len();
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

extendr_module! {
    mod indexing;
    fn a5_lonlat_to_cell_rs;
    fn a5_cell_to_lonlat_rs;
}
