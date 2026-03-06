use extendr_api::prelude::*;
use rayon::prelude::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;

static NUM_THREADS: AtomicUsize = AtomicUsize::new(1);
static POOL: Mutex<Option<rayon::ThreadPool>> = Mutex::new(None);

pub(crate) fn get_num_threads() -> usize {
    NUM_THREADS.load(Ordering::Relaxed)
}

fn set_num_threads(n: usize) {
    let n = n.max(1);
    NUM_THREADS.store(n, Ordering::Relaxed);
    if n > 1 {
        let pool = rayon::ThreadPoolBuilder::new()
            .num_threads(n)
            .build()
            .expect("failed to build thread pool");
        *POOL.lock().unwrap() = Some(pool);
    } else {
        *POOL.lock().unwrap() = None;
    }
}

/// Run closure on the rayon pool if threads > 1, otherwise run directly.
pub(crate) fn maybe_par<F, R>(f: F) -> R
where
    F: FnOnce() -> R + Send,
    R: Send,
{
    let guard = POOL.lock().unwrap();
    match guard.as_ref() {
        Some(pool) => pool.install(f),
        None => f(),
    }
}

/// Extract a u64 from a raw(8) Robj (little-endian). Returns None for NULL/NA.
pub(crate) fn raw_to_u64(robj: &Robj) -> Option<u64> {
    if robj.is_null() {
        return None;
    }
    let slice = robj.as_raw_slice()?;
    if slice.len() != 8 {
        return None;
    }
    Some(u64::from_le_bytes(slice[..8].try_into().unwrap()))
}

/// Convert a u64 to a raw(8) Robj (little-endian).
pub(crate) fn u64_to_raw(id: u64) -> Robj {
    let bytes = id.to_le_bytes();
    Robj::from(bytes.as_slice())
}

/// Apply a fallible function to each cell blob, parallelising when threads > 1.
///
/// NULL elements in the list = NA; the closure should return `None` on
/// parse/conversion errors (mapped to NA in R).
pub(crate) fn map_cells<T, F>(cells: &List, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(u64) -> Option<T> + Send + Sync,
{
    let n = cells.len();
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                let robj = cells.elt(i).unwrap_or_default();
                raw_to_u64(&robj).and_then(|id| f(id))
            })
            .collect()
    } else {
        let inputs: Vec<Option<u64>> = (0..n)
            .map(|i| {
                let robj = cells.elt(i).unwrap_or_default();
                raw_to_u64(&robj)
            })
            .collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt| opt.and_then(|id| f(id)))
                .collect()
        })
    }
}

/// Apply a fallible function to pairs of cell blobs, parallelising when threads > 1.
pub(crate) fn map_cell_pairs<T, F>(a: &List, b: &List, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(u64, u64) -> Option<T> + Send + Sync,
{
    let n = a.len();
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                let ra = a.elt(i).unwrap_or_default();
                let rb = b.elt(i).unwrap_or_default();
                let id_a = raw_to_u64(&ra)?;
                let id_b = raw_to_u64(&rb)?;
                f(id_a, id_b)
            })
            .collect()
    } else {
        let inputs: Vec<(Option<u64>, Option<u64>)> = (0..n)
            .map(|i| {
                let ra = a.elt(i).unwrap_or_default();
                let rb = b.elt(i).unwrap_or_default();
                (raw_to_u64(&ra), raw_to_u64(&rb))
            })
            .collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|(oa, ob)| {
                    let a_id = (*oa)?;
                    let b_id = (*ob)?;
                    f(a_id, b_id)
                })
                .collect()
        })
    }
}

/// Build a List of raw(8) from a Vec<Option<u64>>.
pub(crate) fn u64s_to_list(results: Vec<Option<u64>>) -> List {
    let values: Vec<Robj> = results
        .into_iter()
        .map(|r| match r {
            Some(id) => u64_to_raw(id),
            None => ().into(),
        })
        .collect();
    List::from_values(values)
}

/// Convert a list of raw(8) blobs to hex strings (zero-padded to 16 chars).
#[extendr]
fn blob_to_hex_rs(cells: List) -> Strings {
    let n = cells.len();
    let mut out = Strings::new(n);
    for i in 0..n {
        let robj = cells.elt(i).unwrap_or_default();
        match raw_to_u64(&robj) {
            Some(id) => out.set_elt(i, Rstr::from(format!("{:016x}", id))),
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Convert hex strings to a list of raw(8) blobs.
#[extendr]
fn hex_to_blob_rs(cells: Strings) -> List {
    let n = cells.len();
    let values: Vec<Robj> = (0..n)
        .map(|i| {
            let s = &cells[i];
            if s.is_na() {
                ().into()
            } else {
                match a5::hex_to_u64(s.as_str()) {
                    Ok(id) => u64_to_raw(id),
                    Err(_) => ().into(),
                }
            }
        })
        .collect();
    List::from_values(values)
}

#[extendr]
fn a5_set_threads_rs(n: i32) {
    set_num_threads(n as usize);
}

#[extendr]
fn a5_get_threads_rs() -> i32 {
    get_num_threads() as i32
}

extendr_module! {
    mod threading;
    fn a5_set_threads_rs;
    fn a5_get_threads_rs;
    fn blob_to_hex_rs;
    fn hex_to_blob_rs;
}
