use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::hilo::map_cells;

pub(crate) const BOUNDARY_OPTS_CLOSED: a5::core::cell::CellToBoundaryOptions =
    a5::core::cell::CellToBoundaryOptions {
        closed_ring: true,
        segments: None,
    };

pub(crate) const BOUNDARY_OPTS_OPEN: a5::core::cell::CellToBoundaryOptions =
    a5::core::cell::CellToBoundaryOptions {
        closed_ring: false,
        segments: None,
    };

/// Encode a slice of LonLat coordinates as a WKB Polygon (little-endian, one ring).
pub(crate) fn lonlats_to_wkb(coords: &[a5::LonLat]) -> Vec<u8> {
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

/// Get boundary polygons for A5 cells as WKT strings.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A character vector of WKT POLYGON strings.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_rs(
    hi: Doubles,
    lo: Doubles,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> Strings {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };

    let results = map_cells(&hi, &lo, |id| {
        let opts = a5::core::cell::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        let boundary = a5::cell_to_boundary(id, Some(opts)).ok()?;
        let coords: Vec<String> = boundary
            .iter()
            .map(|ll| format!("{} {}", ll.longitude(), ll.latitude()))
            .collect();
        Some(format!("POLYGON (({}))", coords.join(", ")))
    });

    let n = hi.len();
    let mut out = Strings::new(n);
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(s) => out.set_elt(i, Rstr::from(s)),
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Get boundary polygons for A5 cells as WKB raw vectors.
///
/// @param hi,lo Double vectors (hi/lo u32 halves of cell IDs).
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A list of raw vectors (WKB bytes) or NULL for NA cells.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_wkb_rs(
    hi: Doubles,
    lo: Doubles,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> List {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };

    let results = map_cells(&hi, &lo, |id| {
        let opts = a5::core::cell::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        let boundary = a5::cell_to_boundary(id, Some(opts)).ok()?;
        Some(lonlats_to_wkb(&boundary))
    });

    let values: Vec<Robj> = results
        .into_iter()
        .map(|r| match r {
            Some(wkb) => Robj::from(wkb),
            None => ().into(),
        })
        .collect();
    List::from_values(values)
}

extendr_module! {
    mod boundary;
    fn a5_cell_to_boundary_rs;
    fn a5_cell_to_boundary_wkb_rs;
}
