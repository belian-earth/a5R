use extendr_api::prelude::*;
use std::sync::atomic::{AtomicU32, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

static NUM_THREADS: AtomicUsize = AtomicUsize::new(1);
static POOL: Mutex<Option<Arc<rayon::ThreadPool>>> = Mutex::new(None);
// The process that built POOL. A forked child (parallel::mclapply(),
// future::multicore) inherits the pool but not its threads, so work sent to
// it would wait forever: in any other process a5R runs on one thread.
static POOL_PID: AtomicU32 = AtomicU32::new(0);

fn in_pool_process() -> bool {
    POOL_PID.load(Ordering::Relaxed) == std::process::id()
}

pub(crate) fn get_num_threads() -> usize {
    let n = NUM_THREADS.load(Ordering::Relaxed);
    if n > 1 && !in_pool_process() {
        1
    } else {
        n
    }
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
    let inherited = !in_pool_process();
    let old = std::mem::replace(&mut *pool(), new_pool);
    if inherited {
        // Dropping a pool inherited through fork() would signal threads that
        // do not exist in this process.
        std::mem::forget(old);
    }
    POOL_PID.store(std::process::id(), Ordering::Relaxed);
    NUM_THREADS.store(n, Ordering::Relaxed);
    Ok(())
}

/// Run closure on the rayon pool if threads > 1, otherwise run directly.
pub(crate) fn maybe_par<F, R>(f: F) -> R
where
    F: FnOnce() -> R + Send,
    R: Send,
{
    let current = if in_pool_process() { pool().clone() } else { None };
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

/// Panic inside the thread pool, for the test that a panic in a parallel call
/// leaves the pool and later calls working.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_test_pool_panic_rs() {
    use rayon::prelude::*;
    maybe_par(|| {
        (0..64).into_par_iter().for_each(|i| {
            if i == 63 {
                panic!("a5R test panic");
            }
        })
    })
}

extendr_module! {
    mod threading;
    fn a5_test_pool_panic_rs;
    fn a5_set_threads_rs;
    fn a5_get_threads_rs;
}
