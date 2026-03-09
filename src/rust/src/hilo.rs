use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::threading::{get_num_threads, maybe_par};

// --- hi/lo double ↔ u64 conversion helpers ---

/// Combine hi/lo f64 halves into a u64. Returns None if either is NA/NaN.
#[inline]
pub(crate) fn hilo_to_u64(hi: f64, lo: f64) -> Option<u64> {
    if hi.is_nan() || lo.is_nan() {
        return None;
    }
    Some(((hi as u64) << 32) | (lo as u64))
}

/// Split a u64 into hi/lo f64 halves.
#[inline]
pub(crate) fn u64_to_hilo(id: u64) -> (f64, f64) {
    ((id >> 32) as f64, (id & 0xFFFFFFFF) as f64)
}

/// Build a named list(hi = Doubles, lo = Doubles) from a Vec<Option<u64>>.
pub(crate) fn u64s_to_hilo_list(values: Vec<Option<u64>>) -> List {
    let n = values.len();
    let mut hi = Doubles::new(n);
    let mut lo = Doubles::new(n);
    for (i, v) in values.into_iter().enumerate() {
        match v {
            Some(id) => {
                let (h, l) = u64_to_hilo(id);
                hi.set_elt(i, Rfloat::from(h));
                lo.set_elt(i, Rfloat::from(l));
            }
            None => {
                hi.set_elt(i, Rfloat::na());
                lo.set_elt(i, Rfloat::na());
            }
        }
    }
    list!(hi = hi, lo = lo)
}

/// Apply a fallible function to each cell, parallelising when threads > 1.
///
/// NA inputs (NaN in hi or lo) produce `None`; the closure should return
/// `None` on errors (mapped to NA in R).
pub(crate) fn map_cells<T, F>(hi: &Doubles, lo: &Doubles, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(u64) -> Option<T> + Send + Sync,
{
    let n = hi.len();
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                hilo_to_u64(hi[i].inner(), lo[i].inner()).and_then(|id| f(id))
            })
            .collect()
    } else {
        let inputs: Vec<Option<u64>> = (0..n)
            .map(|i| hilo_to_u64(hi[i].inner(), lo[i].inner()))
            .collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt| opt.and_then(|id| f(id)))
                .collect()
        })
    }
}

/// Apply a fallible function to pairs of cells, parallelising when threads > 1.
pub(crate) fn map_cell_pairs<T, F>(
    hi_a: &Doubles,
    lo_a: &Doubles,
    hi_b: &Doubles,
    lo_b: &Doubles,
    f: F,
) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(u64, u64) -> Option<T> + Send + Sync,
{
    let n = hi_a.len();
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                let a = hilo_to_u64(hi_a[i].inner(), lo_a[i].inner())?;
                let b = hilo_to_u64(hi_b[i].inner(), lo_b[i].inner())?;
                f(a, b)
            })
            .collect()
    } else {
        let inputs: Vec<(Option<u64>, Option<u64>)> = (0..n)
            .map(|i| {
                (
                    hilo_to_u64(hi_a[i].inner(), lo_a[i].inner()),
                    hilo_to_u64(hi_b[i].inner(), lo_b[i].inner()),
                )
            })
            .collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|(oa, ob)| {
                    let a = (*oa)?;
                    let b = (*ob)?;
                    f(a, b)
                })
                .collect()
        })
    }
}

/// Convert hi/lo doubles to hex strings (zero-padded to 16 chars).
/// @noRd
/// @keywords internal
#[extendr]
fn hilo_to_hex_rs(hi: Doubles, lo: Doubles) -> Strings {
    let n = hi.len();
    let mut out = Strings::new(n);
    for i in 0..n {
        match hilo_to_u64(hi[i].inner(), lo[i].inner()) {
            Some(id) => out.set_elt(i, Rstr::from(format!("{:016x}", id))),
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Convert hex strings to hi/lo doubles.
/// Returns list(hi = double(), lo = double()).
/// @noRd
/// @keywords internal
#[extendr]
fn hex_to_hilo_rs(cells: Strings) -> List {
    let n = cells.len();
    let mut hi = Doubles::new(n);
    let mut lo = Doubles::new(n);
    for i in 0..n {
        let s = &cells[i];
        if s.is_na() {
            hi.set_elt(i, Rfloat::na());
            lo.set_elt(i, Rfloat::na());
        } else {
            match a5::hex_to_u64(s.as_str()) {
                Ok(id) => {
                    let (h, l) = u64_to_hilo(id);
                    hi.set_elt(i, Rfloat::from(h));
                    lo.set_elt(i, Rfloat::from(l));
                }
                Err(_) => {
                    hi.set_elt(i, Rfloat::na());
                    lo.set_elt(i, Rfloat::na());
                }
            }
        }
    }
    list!(hi = hi, lo = lo)
}

/// Convert a list of raw(8) vectors (little-endian u64) to hi/lo doubles.
/// NULL elements produce NA.
/// Returns list(hi = double(), lo = double()).
/// @noRd
/// @keywords internal
#[extendr]
fn raw8_to_hilo_rs(blobs: List) -> List {
    let n = blobs.len();
    let mut hi = Doubles::new(n);
    let mut lo = Doubles::new(n);
    for i in 0..n {
        let robj = blobs.elt(i).unwrap();
        if robj.is_null() || robj.rtype() != Rtype::Raw {
            hi.set_elt(i, Rfloat::na());
            lo.set_elt(i, Rfloat::na());
        } else if let Some(slice) = robj.as_raw_slice() {
            if slice.len() == 8 {
                let id = u64::from_le_bytes(slice[..8].try_into().unwrap());
                let (h, l) = u64_to_hilo(id);
                hi.set_elt(i, Rfloat::from(h));
                lo.set_elt(i, Rfloat::from(l));
            } else {
                hi.set_elt(i, Rfloat::na());
                lo.set_elt(i, Rfloat::na());
            }
        } else {
            hi.set_elt(i, Rfloat::na());
            lo.set_elt(i, Rfloat::na());
        }
    }
    list!(hi = hi, lo = lo)
}

/// Convert hi/lo doubles to a list of raw(8) vectors (little-endian u64).
/// NA inputs produce NULL elements.
/// @noRd
/// @keywords internal
#[extendr]
fn hilo_to_raw8_rs(hi: Doubles, lo: Doubles) -> List {
    let n = hi.len();
    let mut out: Vec<Robj> = Vec::with_capacity(n);
    for i in 0..n {
        match hilo_to_u64(hi[i].inner(), lo[i].inner()) {
            Some(id) => {
                let bytes = id.to_le_bytes();
                out.push(Robj::from(bytes.as_slice()));
            }
            None => {
                out.push(().into()); // NULL for NA
            }
        }
    }
    List::from_values(out)
}

extendr_module! {
    mod hilo;
    fn hilo_to_hex_rs;
    fn hex_to_hilo_rs;
    fn raw8_to_hilo_rs;
    fn hilo_to_raw8_rs;
}
