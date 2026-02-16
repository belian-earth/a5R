use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

// ---------------------------------------------------------------------------
// Core indexing
// ---------------------------------------------------------------------------

/// Convert longitude/latitude coordinates to A5 cell indices.
///
/// Vectorised over `lon`, `lat`, and `resolution`.
///
/// @param lon Numeric vector of longitudes (degrees).
/// @param lat Numeric vector of latitudes (degrees).
/// @param resolution Integer vector of resolutions (0-30).
/// @return A character vector of cell IDs (hex-encoded).
/// @export
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
/// @return A list with `lon` and `lat` numeric vectors.
/// @export
#[extendr]
fn a5_cell_to_lonlat_rs(cell: Strings) -> List {
    let n = cell.len();
    let mut lon_out = Doubles::new(n);
    let mut lat_out = Doubles::new(n);
    for i in 0..n {
        let s = cell[i];
        if s.is_na() {
            lon_out.set_elt(i, Rfloat::na());
            lat_out.set_elt(i, Rfloat::na());
            continue;
        }
        match a5::hex_to_u64(s.as_str()) {
            Ok(id) => match a5::cell_to_lonlat(id) {
                Ok(ll) => {
                    lon_out.set_elt(i, Rfloat::from(ll.longitude()));
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

/// Get boundary polygon vertices for A5 cells.
///
/// @param cell Character vector of hex-encoded cell IDs.
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A list of lists, each with `lon` and `lat` numeric vectors.
/// @export
#[extendr]
fn a5_cell_to_boundary_rs(
    cell: Strings,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> List {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };
    let n = cell.len();
    let mut items: Vec<Robj> = Vec::with_capacity(n);
    for i in 0..n {
        let s = cell[i];
        if s.is_na() {
            items.push(list!(lon = Rfloat::na(), lat = Rfloat::na()).into());
            continue;
        }
        let opts = a5::core::cell::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        match a5::hex_to_u64(s.as_str()) {
            Ok(id) => match a5::cell_to_boundary(id, Some(opts)) {
                Ok(boundary) => {
                    let lons: Vec<f64> = boundary.iter().map(|ll| ll.longitude()).collect();
                    let lats: Vec<f64> = boundary.iter().map(|ll| ll.latitude()).collect();
                    items.push(list!(lon = lons, lat = lats).into());
                }
                Err(_) => {
                    items.push(list!(lon = Rfloat::na(), lat = Rfloat::na()).into());
                }
            },
            Err(_) => {
                items.push(list!(lon = Rfloat::na(), lat = Rfloat::na()).into());
            }
        }
    }
    List::from_values(items)
}

// ---------------------------------------------------------------------------
// Cell info
// ---------------------------------------------------------------------------

/// Get the area (in square metres) of cells at a given resolution.
///
/// @param resolution Integer vector of resolutions (0-30).
/// @return Numeric vector of areas in square metres.
/// @export
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
/// @param resolution Integer scalar (0-30).
/// @return Numeric scalar (as double, since R has no u64).
/// @export
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
/// @export
#[extendr]
fn a5_get_resolution_rs(cell: Strings) -> Integers {
    let n = cell.len();
    let mut out = Integers::new(n);
    for i in 0..n {
        let s = cell[i];
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
/// @export
#[extendr]
fn a5_cell_to_parent_rs(cell: Strings, parent_resolution: Nullable<i32>) -> Strings {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let n = cell.len();
    let mut out = Strings::new(n);
    for i in 0..n {
        let s = cell[i];
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
/// @export
#[extendr]
fn a5_cell_to_children_rs(cell: &str, child_resolution: Nullable<i32>) -> Strings {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    match a5::hex_to_u64(cell) {
        Ok(id) => match a5::cell_to_children(id, cres) {
            Ok(children) => {
                children
                    .iter()
                    .map(|c| Rstr::from(a5::u64_to_hex(*c)))
                    .collect::<Strings>()
            }
            Err(e) => {
                panic!("{}", e);
            }
        },
        Err(e) => {
            panic!("{}", e);
        }
    }
}

// ---------------------------------------------------------------------------
// Resolution-0 cells
// ---------------------------------------------------------------------------

/// Get all 12 resolution-0 root cells.
///
/// @return Character vector of 12 hex-encoded cell IDs.
/// @export
#[extendr]
fn a5_get_res0_cells_rs() -> Strings {
    match a5::get_res0_cells() {
        Ok(cells) => cells
            .iter()
            .map(|c| Rstr::from(a5::u64_to_hex(*c)))
            .collect::<Strings>(),
        Err(e) => {
            panic!("{}", e);
        }
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
/// @export
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
        Err(e) => {
            panic!("{}", e);
        }
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param cells Character vector of hex-encoded cell IDs.
/// @param target_resolution Integer: the resolution to expand to.
/// @return Character vector of uncompacted hex-encoded cell IDs.
/// @export
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
        Err(e) => {
            panic!("{}", e);
        }
    }
}

// ---------------------------------------------------------------------------
// Hex utilities
// ---------------------------------------------------------------------------

/// Validate hex cell IDs.
///
/// @param cell Character vector of hex strings to validate.
/// @return Logical vector indicating validity.
/// @export
#[extendr]
fn a5_is_valid_cell_rs(cell: Strings) -> Logicals {
    let n = cell.len();
    let mut out = Logicals::new(n);
    for i in 0..n {
        let s = cell[i];
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
// Module registration
// ---------------------------------------------------------------------------

extendr_module! {
    mod a5R;
    fn a5_lonlat_to_cell_rs;
    fn a5_cell_to_lonlat_rs;
    fn a5_cell_to_boundary_rs;
    fn a5_cell_area_rs;
    fn a5_get_num_cells_rs;
    fn a5_get_resolution_rs;
    fn a5_cell_to_parent_rs;
    fn a5_cell_to_children_rs;
    fn a5_get_res0_cells_rs;
    fn a5_compact_rs;
    fn a5_uncompact_rs;
    fn a5_is_valid_cell_rs;
}
