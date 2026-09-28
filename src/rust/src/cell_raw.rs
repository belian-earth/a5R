use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::threading::{get_num_threads, maybe_par};

// --- NA sentinel and stored byte layout ---
// NA is the id 0xFC00_0000_0000_0000, which is never a valid cell: at
// resolutions 0-29 its top 6 bits give quintant 63, and it does not decode as
// a resolution-30 cell either. Only the full id is the sentinel. A top byte of
// 0xFC alone is not: resolution-30 ids keep only 5, 3 or 1 quintant bits at
// the top, so valid cells in quintants 31, 39 and 41 can start with 0xFC.
pub(crate) const NA_SENTINEL: u64 = 0xFC00_0000_0000_0000;

// The rcrd fields b1..b8 hold the id's little-endian bytes, except that b8
// is stored XOR 0xFC. vctrs fills gaps (an NA index, `x[i] <- NA`,
// vec_init(), unmatched join rows) with 00 bytes; under this encoding eight
// 00 bytes decode to NA_SENTINEL, not to the world cell (id 0). Encoding and
// decoding are the same operation.
pub(crate) const B8_MASK: u8 = 0xFC;

#[inline]
fn encode(id: u64) -> [u8; 8] {
    let mut b = id.to_le_bytes();
    b[7] ^= B8_MASK;
    b
}

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
        //
        // Fields are looked up by iterating the list's names rather than via
        // `dollar()`, which evaluates an R-level `$` call per field (about
        // 1.5 µs each) and dominated the cost of scalar operations.
        let mut slices: [Option<&'a [u8]>; 8] = [None; 8];
        for (name, robj) in list.iter() {
            let j = match name {
                "b1" => 0,
                "b2" => 1,
                "b3" => 2,
                "b4" => 3,
                "b5" => 4,
                "b6" => 5,
                "b7" => 6,
                "b8" => 7,
                _ => continue,
            };
            let slice = robj.as_raw_slice().expect("field is not raw");
            slices[j] = Some(unsafe { std::mem::transmute::<&[u8], &'a [u8]>(slice) });
        }
        let slices = slices.map(|s| s.expect("missing field in cell list"));
        let len = slices[0].len();
        CellSlices { slices, len }
    }

    /// Get the u64 cell ID at index i, or None for the NA sentinel.
    #[inline]
    pub fn get(&self, i: usize) -> Option<u64> {
        let bytes = [
            self.slices[0][i], self.slices[1][i], self.slices[2][i], self.slices[3][i],
            self.slices[4][i], self.slices[5][i], self.slices[6][i],
            self.slices[7][i] ^ B8_MASK,
        ];
        let id = u64::from_le_bytes(bytes);
        if id == NA_SENTINEL { None } else { Some(id) }
    }
}

// --- Output builder ---

/// Build a named list(b1 = Raw, ..., b8 = Raw) from a Vec<Option<u64>>.
pub(crate) fn u64s_to_raw8_list(values: Vec<Option<u64>>) -> List {
    let n = values.len();
    let mut bufs: [Vec<u8>; 8] = std::array::from_fn(|_| vec![0u8; n]);
    for (i, v) in values.iter().enumerate() {
        // None encodes NA_SENTINEL, which is stored as eight 00 bytes.
        let bytes = match v {
            Some(id) => encode(*id),
            None => [0u8; 8],
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
/// Apply a one-to-many function to every cell.
///
/// With `simplify` the results are concatenated in input order into one
/// b1..b8 raw list. Otherwise each input becomes its own fully formed
/// `a5_cell` (class attribute set here, so R only wraps the list), which is
/// far cheaper than chopping the flat vector on the R side. An NA input
/// contributes nothing (an empty element). Runs in parallel when threads are
/// enabled; the first error aborts.
pub(crate) fn one_to_many<F>(cells: &List, name: &str, simplify: bool, f: F) -> Robj
where
    F: Fn(u64) -> std::result::Result<Vec<u64>, String> + Send + Sync,
{
    let results = map_cells(cells, |id| Some(f(id)));
    let unwrap = |r: Option<std::result::Result<Vec<u64>, String>>| -> Vec<Option<u64>> {
        match r {
            Some(Ok(v)) => v.into_iter().map(Some).collect(),
            Some(Err(e)) => throw_r_error(format!("{} failed: {}", name, e)),
            None => Vec::new(),
        }
    };
    if simplify {
        let mut flat: Vec<Option<u64>> = Vec::new();
        for r in results {
            flat.extend(unwrap(r));
        }
        return u64s_to_raw8_list(flat).into();
    }
    let elements: Vec<Robj> = results
        .into_iter()
        .map(|r| {
            let mut cell: Robj = u64s_to_raw8_list(unwrap(r)).into();
            cell.set_class(["a5_cell", "vctrs_rcrd", "vctrs_vctr"])
                .expect("set class on a5_cell");
            cell
        })
        .collect();
    List::from_values(elements).into()
}

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

/// NA test for every cell: the full-id sentinel check, in one pass.
/// @noRd
/// @keywords internal
#[extendr]
fn cells_is_na_rs(cells: List) -> Robj {
    let cs = CellSlices::from_list(&cells);
    // Stored b8 is 00 only for the sentinel and for ids whose top byte is
    // 0xFC; the full check runs for those alone.
    let b8 = cs.slices[7];
    let na: Vec<bool> = (0..cs.len)
        .map(|i| b8[i] == 0 && cs.get(i).is_none())
        .collect();
    Robj::from(na)
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
    fn cells_is_na_rs;
    fn raw8_to_hex_rs;
    fn hex_to_raw8_rs;
    fn blobs_to_raw8_rs;
    fn raw8_to_blobs_rs;
}
