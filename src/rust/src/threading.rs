use extendr_api::prelude::*;
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
