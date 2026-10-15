use extendr_api::prelude::*;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

static NUM_THREADS: AtomicUsize = AtomicUsize::new(1);
static POOL: Mutex<Option<Arc<rayon::ThreadPool>>> = Mutex::new(None);

pub(crate) fn get_num_threads() -> usize {
    NUM_THREADS.load(Ordering::Relaxed)
}

// The lock is only held to swap or clone the pool, never while user work runs,
// so a panic inside a parallel call cannot poison it. Recover anyway.
fn pool() -> MutexGuard<'static, Option<Arc<rayon::ThreadPool>>> {
    POOL.lock().unwrap_or_else(PoisonError::into_inner)
}

fn set_num_threads(n: usize) -> std::result::Result<(), String> {
    let new_pool = if n > 1 {
        let p = rayon::ThreadPoolBuilder::new()
            .num_threads(n)
            .build()
            .map_err(|e| format!("failed to build a thread pool of {n} threads: {e}"))?;
        Some(Arc::new(p))
    } else {
        None
    };
    *pool() = new_pool;
    NUM_THREADS.store(n, Ordering::Relaxed);
    Ok(())
}

/// Run closure on the rayon pool if threads > 1, otherwise run directly.
pub(crate) fn maybe_par<F, R>(f: F) -> R
where
    F: FnOnce() -> R + Send,
    R: Send,
{
    let current = pool().clone();
    match current {
        Some(p) => p.install(f),
        None => f(),
    }
}

#[extendr]
fn a5_set_threads_rs(n: i32) -> extendr_api::Result<()> {
    if n < 1 {
        return Err(Error::Other(format!("`n` must be at least 1, not {n}.")));
    }
    set_num_threads(n as usize).map_err(Error::Other)
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
