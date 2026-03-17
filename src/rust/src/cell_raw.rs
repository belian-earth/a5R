use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::threading::{get_num_threads, maybe_par};

// --- NA sentinel ---
// A5 cell IDs encode a quintant (0–59) in the top 6 bits. Quintant 63
// (binary 111111) is guaranteed invalid, so 0xFC00_0000_0000_0000 can
// never be a real cell. In little-endian layout the most-significant byte
// (b8) is 0xFC — this is what the R-side is.na() method checks.
// Any input that decodes to NA_SENTINEL is treated as missing data.
pub(crate) const NA_SENTINEL: u64 = 0xFC00_0000_0000_0000;
pub(crate) const NA_BYTES: [u8; 8] = NA_SENTINEL.to_le_bytes();

// --- Cell byte slice accessor ---

/// Extracts 8 raw byte slices from an R List (the rcrd fields b1..b8).
pub(crate) struct CellSlices<'a> {
    pub slices: [&'a [u8]; 8],
    pub len: usize,
}

impl<'a> CellSlices<'a> {
    pub fn from_list(list: &'a List) -> Self {
        // SAFETY: Each field (b1..b8) is a RAWSXP owned by the R list.
        // dollar() returns a temporary Robj wrapper, but as_raw_slice()
        // yields a pointer into the RAWSXP's data block, which is kept
        // alive by R's protection of the List for lifetime 'a. Dropping
        // the Robj wrapper does not free the underlying R allocation.
        let names = ["b1", "b2", "b3", "b4", "b5", "b6", "b7", "b8"];
        let mut slices: [&'a [u8]; 8] = [&[]; 8];
        for (j, name) in names.iter().enumerate() {
            let robj = list.dollar(name).expect("missing field in cell list");
            let slice = robj.as_raw_slice().expect("field is not raw");
            slices[j] = unsafe { std::mem::transmute::<&[u8], &'a [u8]>(slice) };
        }
        let len = slices[0].len();
        CellSlices { slices, len }
    }

    /// Get the u64 cell ID at index i. Returns None if b8 == 0xFC (NA sentinel).
    /// Checks only b8 (the MSB in little-endian) to match the R-side is.na()
    /// check. Any cell with b8 == 0xFC has quintant 63, which is always
    /// invalid in A5, so this is safe.
    #[inline]
    pub fn get(&self, i: usize) -> Option<u64> {
        if self.slices[7][i] == NA_BYTES[7] {
            return None;
        }
        let bytes = [
            self.slices[0][i], self.slices[1][i], self.slices[2][i], self.slices[3][i],
            self.slices[4][i], self.slices[5][i], self.slices[6][i], self.slices[7][i],
        ];
        Some(u64::from_le_bytes(bytes))
    }
}

// --- Output builder ---

/// Build a named list(b1 = Raw, ..., b8 = Raw) from a Vec<Option<u64>>.
pub(crate) fn u64s_to_raw8_list(values: Vec<Option<u64>>) -> List {
    let n = values.len();
    let mut bufs: [Vec<u8>; 8] = std::array::from_fn(|_| vec![0u8; n]);
    for (i, v) in values.iter().enumerate() {
        let bytes = match v {
            Some(id) => id.to_le_bytes(),
            None => NA_BYTES,
        };
        for j in 0..8 {
            bufs[j][i] = bytes[j];
        }
    }
    list!(
        b1 = Robj::from(bufs[0].as_slice()),
        b2 = Robj::from(bufs[1].as_slice()),
        b3 = Robj::from(bufs[2].as_slice()),
        b4 = Robj::from(bufs[3].as_slice()),
        b5 = Robj::from(bufs[4].as_slice()),
        b6 = Robj::from(bufs[5].as_slice()),
        b7 = Robj::from(bufs[6].as_slice()),
        b8 = Robj::from(bufs[7].as_slice())
    )
}

/// Extract a single u64 from a List (for scalar cell functions).
pub(crate) fn scalar_cell_from_list(list: &List) -> Option<u64> {
    let cs = CellSlices::from_list(list);
    cs.get(0)
}

// --- Vectorised mappers ---

/// Apply a fallible function to each cell, parallelising when threads > 1.
pub(crate) fn map_cells<T, F>(cells: &List, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(u64) -> Option<T> + Send + Sync,
{
    let cs = CellSlices::from_list(cells);
    let n = cs.len;
    if get_num_threads() <= 1 {
        (0..n).map(|i| cs.get(i).and_then(|id| f(id))).collect()
    } else {
        let inputs: Vec<Option<u64>> = (0..n).map(|i| cs.get(i)).collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt| opt.and_then(|id| f(id)))
                .collect()
        })
    }
}

/// Apply a fallible function to pairs of cells, parallelising when threads > 1.
pub(crate) fn map_cell_pairs<T, F>(a: &List, b: &List, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(u64, u64) -> Option<T> + Send + Sync,
{
    let cs_a = CellSlices::from_list(a);
    let cs_b = CellSlices::from_list(b);
    let n = cs_a.len;
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                let a = cs_a.get(i)?;
                let b = cs_b.get(i)?;
                f(a, b)
            })
            .collect()
    } else {
        let inputs: Vec<(Option<u64>, Option<u64>)> =
            (0..n).map(|i| (cs_a.get(i), cs_b.get(i))).collect();
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

/// Collect u64 values from a cell List, skipping NAs.
pub(crate) fn collect_ids(cells: &List) -> Vec<u64> {
    let cs = CellSlices::from_list(cells);
    (0..cs.len).filter_map(|i| cs.get(i)).collect()
}

// --- Exported conversion functions ---

/// Convert cell raw bytes to hex strings (zero-padded to 16 chars).
/// @noRd
/// @keywords internal
#[extendr]
fn raw8_to_hex_rs(cells: List) -> Strings {
    let cs = CellSlices::from_list(&cells);
    let n = cs.len;
    let mut out = Strings::new(n);
    for i in 0..n {
        match cs.get(i) {
            Some(id) => out.set_elt(i, Rstr::from(format!("{:016x}", id))),
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Convert hex strings to cell raw bytes.
/// Returns list(b1 = raw(), ..., b8 = raw()).
/// @noRd
/// @keywords internal
#[extendr]
fn hex_to_raw8_rs(cells: Strings) -> List {
    let n = cells.len();
    let mut values: Vec<Option<u64>> = Vec::with_capacity(n);
    for i in 0..n {
        let s = &cells[i];
        if s.is_na() {
            values.push(None);
        } else {
            match a5::hex_to_u64(s.as_str()) {
                Ok(id) if id != NA_SENTINEL => values.push(Some(id)),
                _ => values.push(None),
            }
        }
    }
    u64s_to_raw8_list(values)
}

/// Convert a list of raw(8) blobs (from Arrow) to cell raw bytes.
/// @noRd
/// @keywords internal
#[extendr]
fn blobs_to_raw8_rs(blobs: List) -> List {
    let n = blobs.len();
    let mut values: Vec<Option<u64>> = Vec::with_capacity(n);
    for i in 0..n {
        let robj = blobs.elt(i).unwrap();
        if robj.is_null() || robj.rtype() != Rtype::Raw {
            values.push(None);
        } else if let Some(slice) = robj.as_raw_slice() {
            if slice.len() == 8 {
                let id = u64::from_le_bytes(slice[..8].try_into().unwrap());
                if id == NA_SENTINEL {
                    values.push(None);
                } else {
                    values.push(Some(id));
                }
            } else {
                values.push(None);
            }
        } else {
            values.push(None);
        }
    }
    u64s_to_raw8_list(values)
}

/// Convert cell raw bytes to a list of raw(8) blobs (for Arrow).
/// NA cells produce NULL elements.
/// @noRd
/// @keywords internal
#[extendr]
fn raw8_to_blobs_rs(cells: List) -> List {
    let cs = CellSlices::from_list(&cells);
    let n = cs.len;
    let mut out: Vec<Robj> = Vec::with_capacity(n);
    for i in 0..n {
        match cs.get(i) {
            Some(id) => {
                let bytes = id.to_le_bytes();
                out.push(Robj::from(bytes.as_slice()));
            }
            None => {
                out.push(().into());
            }
        }
    }
    List::from_values(out)
}

extendr_module! {
    mod cell_raw;
    fn raw8_to_hex_rs;
    fn hex_to_raw8_rs;
    fn blobs_to_raw8_rs;
    fn raw8_to_blobs_rs;
}
