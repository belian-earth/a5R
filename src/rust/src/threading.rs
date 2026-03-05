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

/// Apply a fallible function to each cell string, parallelising when threads > 1.
///
/// NA inputs produce `None`; the closure should return `None` on parse/conversion
/// errors (mapped to NA in R).
pub(crate) fn map_cells<T, F>(cells: &Strings, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(&str) -> Option<T> + Send + Sync,
{
    let n = cells.len();
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                let s = &cells[i];
                if s.is_na() { None } else { f(s.as_str()) }
            })
            .collect()
    } else {
        let inputs: Vec<Option<&str>> = (0..n)
            .map(|i| {
                let s = &cells[i];
                if s.is_na() { None } else { Some(s.as_str()) }
            })
            .collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|opt_s| opt_s.and_then(|s| f(s)))
                .collect()
        })
    }
}

/// Apply a fallible function to pairs of cell strings, parallelising when threads > 1.
///
/// Either input being NA produces `None`; the closure should return `None` on
/// parse/conversion errors (mapped to NA in R).
pub(crate) fn map_cell_pairs<T, F>(a: &Strings, b: &Strings, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(&str, &str) -> Option<T> + Send + Sync,
{
    let n = a.len();
    if get_num_threads() <= 1 {
        (0..n)
            .map(|i| {
                let sa = &a[i];
                let sb = &b[i];
                if sa.is_na() || sb.is_na() {
                    None
                } else {
                    f(sa.as_str(), sb.as_str())
                }
            })
            .collect()
    } else {
        let inputs: Vec<(Option<&str>, Option<&str>)> = (0..n)
            .map(|i| {
                let sa = &a[i];
                let sb = &b[i];
                (
                    if sa.is_na() { None } else { Some(sa.as_str()) },
                    if sb.is_na() { None } else { Some(sb.as_str()) },
                )
            })
            .collect();
        maybe_par(|| {
            inputs
                .par_iter()
                .map(|(oa, ob)| {
                    let a_str = (*oa)?;
                    let b_str = (*ob)?;
                    f(a_str, b_str)
                })
                .collect()
        })
    }
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
}
