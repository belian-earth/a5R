use extendr_api::prelude::*;
use geo::Intersects;
use rayon::prelude::*;
use std::str::FromStr;

use crate::boundary::{BOUNDARY_OPTS_CLOSED, BOUNDARY_OPTS_OPEN};
use crate::threading::{get_num_threads, maybe_par};

struct BBox {
    xmin: f64,
    ymin: f64,
    xmax: f64,
    ymax: f64,
}

fn bboxes_overlap(a: &BBox, b: &BBox) -> bool {
    a.xmin <= b.xmax && a.xmax >= b.xmin && a.ymin <= b.ymax && a.ymax >= b.ymin
}

fn cell_bbox(boundary: &[a5::LonLat]) -> BBox {
    let (mut xmin, mut xmax) = (f64::MAX, f64::MIN);
    let (mut ymin, mut ymax) = (f64::MAX, f64::MIN);
    for ll in boundary {
        xmin = xmin.min(ll.longitude());
        xmax = xmax.max(ll.longitude());
        ymin = ymin.min(ll.latitude());
        ymax = ymax.max(ll.latitude());
    }
    BBox { xmin, ymin, xmax, ymax }
}

/// Buffer distance in degrees, latitude-adjusted.
fn buffer_distance(resolution: i32, max_abs_lat: f64) -> f64 {
    let area_m2 = a5::cell_area(resolution);
    let diameter_m = area_m2.sqrt();
    let cos_lat = (max_abs_lat * std::f64::consts::PI / 180.0).cos();
    if cos_lat < 0.05 {
        return 90.0; // sentinel: skip filtering near poles
    }
    diameter_m / (111000.0 * cos_lat) * 0.5
}

/// Convert A5 cell boundary to a geo::Polygon for intersection testing.
fn cell_to_geo_polygon(cell_id: u64) -> Option<geo::Polygon<f64>> {
    let boundary = a5::cell_to_boundary(cell_id, Some(BOUNDARY_OPTS_CLOSED)).ok()?;
    let coords: Vec<geo::Coord<f64>> = boundary
        .iter()
        .map(|ll| geo::Coord {
            x: ll.longitude(),
            y: ll.latitude(),
        })
        .collect();
    Some(geo::Polygon::new(geo::LineString::from(coords), vec![]))
}

/// Generate a grid of A5 cells covering a bounding box.
///
/// Uses hierarchical descent with bbox filtering entirely in Rust.
///
/// @param xmin,ymin,xmax,ymax Bounding box coordinates.
/// @param resolution Target resolution (0--30).
/// @return Character vector of hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_bbox_rs(xmin: f64, ymin: f64, xmax: f64, ymax: f64, resolution: i32) -> Strings {
    let target = BBox { xmin, ymin, xmax, ymax };
    let max_abs_lat = ymin.abs().max(ymax.abs());

    let mut cells = match a5::get_res0_cells() {
        Ok(c) => c,
        Err(_) => return Strings::new(0),
    };
    let mut current_res: i32 = 0;
    let step: i32 = 3;
    let filter_start: i32 = 3;

    while current_res < resolution {
        let next_res = (current_res + step).min(resolution);
        cells = match a5::uncompact(&cells, next_res) {
            Ok(c) => c,
            Err(_) => return Strings::new(0),
        };
        current_res = next_res;

        if current_res >= filter_start {
            let buf = if current_res < resolution {
                buffer_distance(current_res, max_abs_lat)
            } else {
                0.0
            };
            if buf < 45.0 {
                // skip filtering if near poles
                let buffered = BBox {
                    xmin: target.xmin - buf,
                    ymin: (target.ymin - buf).max(-90.0),
                    xmax: target.xmax + buf,
                    ymax: (target.ymax + buf).min(90.0),
                };
                if get_num_threads() <= 1 {
                    cells.retain(|&cell_id| {
                        a5::cell_to_boundary(cell_id, Some(BOUNDARY_OPTS_OPEN))
                            .map(|b| bboxes_overlap(&cell_bbox(&b), &buffered))
                            .unwrap_or(false)
                    });
                } else {
                    cells = maybe_par(|| {
                        cells
                            .par_iter()
                            .copied()
                            .filter(|&cell_id| {
                                a5::cell_to_boundary(cell_id, Some(BOUNDARY_OPTS_OPEN))
                                    .map(|b| bboxes_overlap(&cell_bbox(&b), &buffered))
                                    .unwrap_or(false)
                            })
                            .collect()
                    });
                }
            }
        }
    }

    cells
        .iter()
        .map(|c| Rstr::from(a5::u64_to_hex(*c)))
        .collect::<Strings>()
}

/// Filter cell IDs to those whose boundary polygons intersect a target geometry.
///
/// @param cells Character vector of hex-encoded cell IDs.
/// @param target_wkt WKT string of the target geometry.
/// @return Character vector of cell IDs that intersect the target.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_grid_intersects_rs(cells: Strings, target_wkt: &str) -> Strings {
    let wkt_obj = match wkt::Wkt::<f64>::from_str(target_wkt) {
        Ok(w) => w,
        Err(_) => return Strings::new(0),
    };
    let target: geo::Geometry<f64> = match geo::Geometry::try_from(wkt_obj) {
        Ok(g) => g,
        Err(_) => return Strings::new(0),
    };

    let n = cells.len();

    if get_num_threads() <= 1 {
        let mut out = Vec::with_capacity(n);
        for i in 0..n {
            let s = &cells[i];
            if s.is_na() {
                continue;
            }
            let keep = a5::hex_to_u64(s.as_str())
                .ok()
                .and_then(|id| cell_to_geo_polygon(id))
                .map(|poly| target.intersects(&poly))
                .unwrap_or(false);
            if keep {
                out.push(Rstr::from(s.as_str()));
            }
        }
        out.into_iter().collect::<Strings>()
    } else {
        let inputs: Vec<Option<&str>> = (0..n)
            .map(|i| {
                let s = &cells[i];
                if s.is_na() { None } else { Some(s.as_str()) }
            })
            .collect();

        let kept: Vec<Option<String>> = maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt_s| {
                    let s = (*opt_s)?;
                    let id = a5::hex_to_u64(s).ok()?;
                    let poly = cell_to_geo_polygon(id)?;
                    if target.intersects(&poly) {
                        Some(s.to_string())
                    } else {
                        None
                    }
                })
                .collect()
        });

        kept.into_iter()
            .flatten()
            .map(|s| Rstr::from(s))
            .collect::<Strings>()
    }
}

extendr_module! {
    mod grid;
    fn a5_grid_bbox_rs;
    fn a5_grid_intersects_rs;
}
