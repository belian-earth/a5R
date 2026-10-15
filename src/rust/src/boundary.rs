use std::fmt::Write;

use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;
use extendr_api::SEXP;

use crate::cell_raw::map_cells;

// R C API entry points. The WKB and WKT outputs hold one R object per cell;
// creating each through extendr registers it in extendr's protection table,
// which costs more than the allocation itself. These build the objects
// directly and store each in the (protected) output vector at once.
#[allow(improper_ctypes)] // SEXP points to an opaque struct
extern "C" {
    fn Rf_allocVector(sexptype: u32, len: isize) -> SEXP;
    fn RAW(x: SEXP) -> *mut u8;
    fn SET_VECTOR_ELT(x: SEXP, i: isize, v: SEXP) -> SEXP;
    fn Rf_mkCharLenCE(s: *const std::os::raw::c_char, len: i32, enc: u32) -> SEXP;
    fn SET_STRING_ELT(x: SEXP, i: isize, v: SEXP);
}

const RAWSXP: u32 = 24;
const CE_UTF8: u32 = 1;

/// Build an R list of raw vectors; `None` leaves the element `NULL`.
fn raw_list(values: &[Option<Vec<u8>>]) -> List {
    let out = List::new(values.len());
    for (i, v) in values.iter().enumerate() {
        if let Some(bytes) = v {
            // SAFETY: called on the R main thread. `out` is protected, and
            // nothing allocates between creating the raw vector and storing
            // it in `out`, so it cannot be collected in between.
            unsafe {
                let raw = Rf_allocVector(RAWSXP, bytes.len() as isize);
                std::ptr::copy_nonoverlapping(bytes.as_ptr(), RAW(raw), bytes.len());
                SET_VECTOR_ELT(out.get(), i as isize, raw);
            }
        }
    }
    out
}

/// Build an R character vector from UTF-8 strings; `None` becomes `NA`.
fn strings_from(values: &[Option<String>]) -> Strings {
    let mut out = Strings::new(values.len());
    for (i, v) in values.iter().enumerate() {
        match v {
            // SAFETY: as in `raw_list`; the CHARSXP is stored at once.
            Some(s) => unsafe {
                let chr = Rf_mkCharLenCE(s.as_ptr().cast(), s.len() as i32, CE_UTF8);
                SET_STRING_ELT(out.get(), i as isize, chr);
            },
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Format a ring as a WKT Polygon.
fn lonlats_to_wkt(coords: &[a5::LonLat]) -> String {
    let mut wkt = String::with_capacity(12 + coords.len() * 40);
    wkt.push_str("POLYGON ((");
    for (j, ll) in coords.iter().enumerate() {
        if j > 0 {
            wkt.push_str(", ");
        }
        write!(wkt, "{} {}", ll.longitude(), ll.latitude()).unwrap();
    }
    wkt.push_str("))");
    wkt
}

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
/// @param cells List with b1..b8 raw vectors.
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A character vector of WKT POLYGON strings.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_rs(
    cells: List,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> Strings {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };

    let results = map_cells(&cells, |id| {
        let opts = a5::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        let boundary = a5::cell_to_boundary(id, Some(opts)).ok()?;
        Some(lonlats_to_wkt(&boundary))
    });
    strings_from(&results)
}

/// Get boundary polygons for A5 cells as WKB raw vectors.
///
/// @param cells List with b1..b8 raw vectors.
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A list of raw vectors (WKB bytes) or NULL for NA cells.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_wkb_rs(
    cells: List,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> List {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };

    let results = map_cells(&cells, |id| {
        let opts = a5::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        let boundary = a5::cell_to_boundary(id, Some(opts)).ok()?;
        Some(lonlats_to_wkb(&boundary))
    });

    raw_list(&results)
}

/// Get boundary vertices for A5 cells as flat coordinate vectors.
///
/// @param cells List with b1..b8 raw vectors.
/// @param closed_ring Logical: should the polygon ring be closed?
/// @param segments Integer: number of interpolation segments per edge.
/// @return A list of `x` and `y` (doubles, every cell's vertices in turn) and
///   `lengths` (integer, vertices per cell; 0 for NA cells).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_boundary_xy_rs(
    cells: List,
    closed_ring: bool,
    segments: Nullable<i32>,
) -> List {
    let seg: Option<i32> = match segments {
        Nullable::NotNull(s) => Some(s),
        Nullable::Null => None,
    };

    let results = map_cells(&cells, |id| {
        let opts = a5::CellToBoundaryOptions {
            closed_ring,
            segments: seg,
        };
        a5::cell_to_boundary(id, Some(opts)).ok()
    });

    let total: usize = results.iter().flatten().map(|b| b.len()).sum();
    let mut x: Robj = Doubles::new(total).into();
    let mut y: Robj = Doubles::new(total).into();
    let mut lengths: Robj = Integers::new(results.len()).into();
    {
        let xs = x.as_real_slice_mut().unwrap();
        let ys = y.as_real_slice_mut().unwrap();
        let ls = lengths.as_integer_slice_mut().unwrap();
        let mut k = 0;
        for (i, r) in results.iter().enumerate() {
            let boundary = match r {
                Some(b) => b,
                None => {
                    ls[i] = 0;
                    continue;
                }
            };
            for ll in boundary {
                xs[k] = ll.longitude();
                ys[k] = ll.latitude();
                k += 1;
            }
            ls[i] = boundary.len() as i32;
        }
    }
    list!(x = x, y = y, lengths = lengths)
}

extendr_module! {
    mod boundary;
    fn a5_cell_to_boundary_rs;
    fn a5_cell_to_boundary_wkb_rs;
    fn a5_cell_to_boundary_xy_rs;
}
