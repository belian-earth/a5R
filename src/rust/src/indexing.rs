use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::cell_raw::{cells_from_fn, par_chunk, CellSlices, PAR_MIN};
use crate::threading::{get_num_threads, maybe_par};

/// Convert longitude/latitude coordinates to A5 cell indices.
///
/// @param lon Numeric vector of longitudes (degrees).
/// @param lat Numeric vector of latitudes (degrees).
/// @param resolution Integer vector of resolutions (0--30).
/// @return A list with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_lonlat_to_cell_rs(lon: Doubles, lat: Doubles, resolution: Integers) -> List {
    let (lon, lat, resolution): (&[Rfloat], &[Rfloat], &[Rint]) = (&lon, &lat, &resolution);
    cells_from_fn(lon.len(), |i| {
        let (lo, la, res) = (lon[i].0, lat[i].0, resolution[i]);
        if !lo.is_finite() || !la.is_finite() || res.is_na() {
            return None;
        }
        a5::lonlat_to_cell(a5::LonLat::new(lo, la), res.0).ok()
    })
}

/// Convert A5 cell indices to longitude/latitude coordinates.
///
/// @param cells List with b1..b8 raw vectors.
/// @param normalise Logical: if TRUE, wrap longitudes to the standard range.
/// @return A list with `lon` and `lat` numeric vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_lonlat_rs(cells: List, normalise: bool) -> List {
    let cs = CellSlices::from_list(&cells);
    let n = cs.len;
    let one = |i: usize| -> (Rfloat, Rfloat) {
        match cs.get(i).and_then(|id| a5::cell_to_lonlat(id).ok()) {
            Some(ll) => {
                let lon = if normalise {
                    ((ll.longitude() + 180.0) % 360.0 + 360.0) % 360.0 - 180.0
                } else {
                    ll.longitude()
                };
                (lon.into(), ll.latitude().into())
            }
            None => (Rfloat::na(), Rfloat::na()),
        }
    };
    let mut lon_out = Doubles::new(n);
    let mut lat_out = Doubles::new(n);
    {
        let (lon, lat): (&mut [Rfloat], &mut [Rfloat]) = (&mut lon_out, &mut lat_out);
        if get_num_threads() <= 1 || n < PAR_MIN {
            for i in 0..n {
                (lon[i], lat[i]) = one(i);
            }
        } else {
            let chunk = par_chunk(n);
            maybe_par(|| {
                lon.par_chunks_mut(chunk)
                    .zip(lat.par_chunks_mut(chunk))
                    .enumerate()
                    .for_each(|(c, (lo, la))| {
                        for k in 0..lo.len() {
                            (lo[k], la[k]) = one(c * chunk + k);
                        }
                    })
            });
        }
    }
    list!(lon = lon_out, lat = lat_out)
}

extendr_module! {
    mod indexing;
    fn a5_lonlat_to_cell_rs;
    fn a5_cell_to_lonlat_rs;
}
