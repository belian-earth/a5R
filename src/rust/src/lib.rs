use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;
use geo::Intersects;
use std::str::FromStr;

// ---------------------------------------------------------------------------
// WKB helpers
// ---------------------------------------------------------------------------

/// Encode a slice of LonLat coordinates as a WKB Polygon (little-endian, one ring).
fn lonlats_to_wkb(coords: &[a5::LonLat]) -> Vec<u8> {
    let n = coords.len();
    let mut buf = Vec::with_capacity(13 + n * 16);
    buf.push(0x01); // little-endian
    buf.extend_from_slice(&3u32.to_le_bytes()); // wkbPolygon
    buf.extend_from_slice(&1u32.to_le_bytes()); // 1 ring
    buf.extend_from_slice(&(n as u32).to_le_bytes()); // point count
    for ll in coords {
        buf.extend_from_slice(&ll.longitude().to_le_bytes());
        buf.extend_from_slice(&ll.latitude().to_le_bytes());
    }
    buf
}

// ---------------------------------------------------------------------------
// Shared constants
// ---------------------------------------------------------------------------

const BOUNDARY_OPTS_CLOSED: a5::core::cell::CellToBoundaryOptions =
    a5::core::cell::CellToBoundaryOptions {
        closed_ring: true,
        segments: None,
    };

const BOUNDARY_OPTS_OPEN: a5::core::cell::CellToBoundaryOptions =
    a5::core::cell::CellToBoundaryOptions {
        closed_ring: false,
        segments: None,
    };

// ---------------------------------------------------------------------------
// Grid helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Core indexing
// ---------------------------------------------------------------------------

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
}

// ---------------------------------------------------------------------------
// Cell boundaries
// ---------------------------------------------------------------------------

/// Get boundary polygons for A5 cells as WKT strings.
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A character vector of WKT POLYGON strings.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_rs(
    cell: Strings,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> Strings {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };
    let n = cell.len();
    let mut out = Strings::new(n);
    for i in 0..n {
        let s = &cell[i];
        if s.is_na() {
            out.set_elt(i, Rstr::na());
            continue;
        }
        let opts = a5::core::cell::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        match a5::hex_to_u64(s.as_str()) {
            Ok(id) => match a5::cell_to_boundary(id, Some(opts)) {
                Ok(boundary) => {
                    let coords: Vec<String> = boundary
                        .iter()
                        .map(|ll| format!("{} {}", ll.longitude(), ll.latitude()))
                        .collect();
                    let wkt = format!("POLYGON (({}))", coords.join(", "));
                    out.set_elt(i, Rstr::from(wkt));
                }
                Err(_) => out.set_elt(i, Rstr::na()),
            },
            Err(_) => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

// ---------------------------------------------------------------------------
// Cell info
// ---------------------------------------------------------------------------

/// Get the area (in square metres) of cells at a given resolution.
///
/// @param resolution Integer vector of resolutions (0--30).
/// @return Numeric vector of areas in square metres.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_area_rs(resolution: Integers) -> Doubles {
    let n = resolution.len();
    let mut out = Doubles::new(n);
    for i in 0..n {
        let r = resolution[i];
        if r.is_na() {
            out.set_elt(i, Rfloat::na());
        } else {
            out.set_elt(i, Rfloat::from(a5::cell_area(r.inner())));
        }
    }
    out
}

/// Get total number of cells at a given resolution.
///
/// @param resolution Integer scalar (0--30).
/// @return Numeric scalar (as double, since R has no u64).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_num_cells_rs(resolution: i32) -> f64 {
    a5::get_num_cells(resolution) as f64
}

// ---------------------------------------------------------------------------
// Hierarchy
// ---------------------------------------------------------------------------

/// Get the resolution of A5 cell indices.
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @return Integer vector of resolutions.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_resolution_rs(cell: Strings) -> Integers {
    let n = cell.len();
    let mut out = Integers::new(n);
    for i in 0..n {
        let s = &cell[i];
        if s.is_na() {
            out.set_elt(i, Rint::na());
            continue;
        }
        match a5::hex_to_u64(s.as_str()) {
            Ok(id) => out.set_elt(i, Rint::from(a5::get_resolution(id))),
            Err(_) => out.set_elt(i, Rint::na()),
        }
    }
    out
}

/// Navigate to parent cell(s).
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @param parent_resolution Integer: target parent resolution. NULL for
///   immediate parent.
/// @return Character vector of hex-encoded parent cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_parent_rs(cell: Strings, parent_resolution: Nullable<i32>) -> Strings {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let n = cell.len();
    let mut out = Strings::new(n);
    for i in 0..n {
        let s = &cell[i];
        if s.is_na() {
            out.set_elt(i, Rstr::na());
            continue;
        }
        match a5::hex_to_u64(s.as_str()) {
            Ok(id) => match a5::cell_to_parent(id, pres) {
                Ok(parent) => out.set_elt(i, Rstr::from(a5::u64_to_hex(parent))),
                Err(_) => out.set_elt(i, Rstr::na()),
            },
            Err(_) => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Get child cells.
///
/// @param cell A single hex-encoded cell ID.
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @return Character vector of hex-encoded child cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(cell: &str, child_resolution: Nullable<i32>) -> Strings {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let id = match a5::hex_to_u64(cell) {
        Ok(id) => id,
        Err(e) => throw_r_error(format!("invalid cell ID: {}", e)),
    };
    match a5::cell_to_children(id, cres) {
        Ok(children) => children
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("cell_to_children failed: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// Resolution-0 cells
// ---------------------------------------------------------------------------

/// Get all 12 resolution-0 root cells.
///
/// @return Character vector of 12 hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_res0_cells_rs() -> Strings {
    match a5::get_res0_cells() {
        Ok(cells) => cells
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("get_res0_cells failed: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// Compact / uncompact
// ---------------------------------------------------------------------------

/// Compact a set of A5 cell IDs.
///
/// Merges sibling groups into their common parent.
///
/// @param cells Character vector of hex-encoded cell IDs.
/// @return Character vector of compacted hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(cells: Strings) -> Strings {
    let ids: Vec<u64> = cells
        .iter()
        .filter(|s| !s.is_na())
        .filter_map(|s| a5::hex_to_u64(s.as_str()).ok())
        .collect();
    match a5::compact(&ids) {
        Ok(compacted) => compacted
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param cells Character vector of hex-encoded cell IDs.
/// @param target_resolution Integer: the resolution to expand to.
/// @return Character vector of uncompacted hex-encoded cell IDs.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(cells: Strings, target_resolution: i32) -> Strings {
    let ids: Vec<u64> = cells
        .iter()
        .filter(|s| !s.is_na())
        .filter_map(|s| a5::hex_to_u64(s.as_str()).ok())
        .collect();
    match a5::uncompact(&ids, target_resolution) {
        Ok(result) => result
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => throw_r_error(format!("uncompact failed: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// Hex utilities
// ---------------------------------------------------------------------------

/// Validate hex cell IDs.
///
/// @param cell Character vector of hex strings to validate.
/// @return Logical vector indicating validity.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_cell_rs(cell: Strings) -> Logicals {
    let n = cell.len();
    let mut out = Logicals::new(n);
    for i in 0..n {
        let s = &cell[i];
        if s.is_na() {
            out.set_elt(i, Rbool::na());
            continue;
        }
        let valid = a5::hex_to_u64(s.as_str()).is_ok();
        out.set_elt(i, Rbool::from(valid));
    }
    out
}

// ---------------------------------------------------------------------------
// WKB boundary output
// ---------------------------------------------------------------------------

/// Get boundary polygons for A5 cells as WKB raw vectors.
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A list of raw vectors (WKB bytes) or NULL for NA cells.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_wkb_rs(
    cell: Strings,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> List {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };
    let n = cell.len();
    let values: Vec<Robj> = (0..n)
        .map(|i| {
            let s = &cell[i];
            if s.is_na() {
                return ().into();
            }
            let opts = a5::core::cell::CellToBoundaryOptions {
                closed_ring,
                segments: seg,
            };
            match a5::hex_to_u64(s.as_str()) {
                Ok(id) => match a5::cell_to_boundary(id, Some(opts)) {
                    Ok(boundary) => Robj::from(lonlats_to_wkb(&boundary)),
                    Err(_) => ().into(),
                },
                Err(_) => ().into(),
            }
        })
        .collect();
    List::from_values(values)
}

// ---------------------------------------------------------------------------
// Grid generation
// ---------------------------------------------------------------------------

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
                cells.retain(|&cell_id| {
                    match a5::cell_to_boundary(cell_id, Some(BOUNDARY_OPTS_OPEN)) {
                        Ok(boundary) => bboxes_overlap(&cell_bbox(&boundary), &buffered),
                        Err(_) => false,
                    }
                });
            }
        }
    }

    cells
        .iter()
        .map(|c| Rstr::from(a5::u64_to_hex(*c)))
        .collect::<Strings>()
}

// ---------------------------------------------------------------------------
// Intersection filtering
// ---------------------------------------------------------------------------

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
}

// ---------------------------------------------------------------------------
// Traversal
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Module registration
// ---------------------------------------------------------------------------

extendr_module! {
    mod a5R;
    fn a5_lonlat_to_cell_rs;
    fn a5_cell_to_lonlat_rs;
    fn a5_cell_to_boundary_rs;
    fn a5_cell_to_boundary_wkb_rs;
    fn a5_cell_area_rs;
    fn a5_get_num_cells_rs;
    fn a5_get_resolution_rs;
    fn a5_cell_to_parent_rs;
    fn a5_cell_to_children_rs;
    fn a5_get_res0_cells_rs;
    fn a5_compact_rs;
    fn a5_uncompact_rs;
    fn a5_is_valid_cell_rs;
    fn a5_grid_bbox_rs;
    fn a5_grid_intersects_rs;
    fn a5_grid_disk_rs;
    fn a5_spherical_cap_rs;
}
