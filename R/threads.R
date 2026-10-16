#' Get or set the number of threads used by a5R
#'
#' Controls the number of threads used for parallel processing in vectorised
#' functions. One thread (the default) runs sequentially with no overhead;
#' more run in parallel via rayon. As with [options()] and [par()],
#' `a5_threads()` reports the current count and `a5_threads(n)` sets it.
#'
#' `a5_threads(n)` returns the previous thread count, so a change can be
#' scoped to a block of code with [with()], as `mirai::daemons()` is:
#' `with(a5_threads(4), expr)` runs `expr` on four threads and then restores
#' the previous count, even if `expr` fails.
#'
#' The count can also be set before the package loads, with the option
#' `a5R.threads` or the environment variable `A5R_NUM_THREADS`.
#'
#' A forked worker, as created by [parallel::mclapply()] or
#' `future::multicore`, inherits the count but not the threads, so a5R runs
#' on one thread there until the worker calls `a5_threads()` itself.
#' Separate-process workers, as from `mirai` or `future::multisession`, start
#' at one thread like any new session.
#'
#' @param n `NULL` (the default) to report the current count, or an integer
#'   scalar of at least 1 to set it. The value returned by an earlier
#'   `a5_threads(n)` call also works.
#' @param data The value of `a5_threads(n)`.
#' @param expr Code to run with that thread count.
#' @param ... Unused.
#' @returns `a5_threads()`: the current count, an integer scalar.
#'   `a5_threads(n)`: the previous count, invisibly, as an `a5_threads`
#'   object. `with()`: the value of `expr`.
#' @export
#' @examples
#' a5_threads()
#'
#' cells <- a5_lonlat_to_cell(runif(1000, -180, 180), runif(1000, -80, 80), 10)
#' b <- with(a5_threads(2), a5_cell_to_boundary(cells))
#' a5_threads()
a5_threads <- function(n = NULL) {
  if (is.null(n)) {
    return(a5_get_threads_rs())
  }
  if (inherits(n, "a5_threads")) n <- as.integer(n)
  n <- vctrs::vec_cast(n, integer())
  check_size1(n)
  if (is.na(n) || n < 1L) {
    a5_abort("argument", "{.arg n} must be a positive integer, not {n}.")
  }
  old <- a5_get_threads_rs()
  a5_set_threads_rs(n)
  invisible(structure(old, class = "a5_threads"))
}

#' @rdname a5_threads
#' @export
with.a5_threads <- function(data, expr, ...) {
  on.exit(a5_threads(data), add = TRUE)
  expr
}

#' @export
print.a5_threads <- function(x, ...) {
  cat("<a5_threads> previous count:", as.integer(x), "\n")
  invisible(x)
}

#' Deprecated thread functions
#'
#' `a5_set_threads()` and `a5_get_threads()` are replaced by [a5_threads()],
#' which both sets and reports the count. They still work but warn.
#'
#' @param n Integer scalar. Number of threads.
#' @returns As [a5_threads()].
#' @keywords internal
#' @export
a5_set_threads <- function(n = 1L) {
  warn_renamed_fn("a5_set_threads", "a5_threads(n)")
  a5_threads(n)
}

#' @rdname a5_set_threads
#' @export
a5_get_threads <- function() {
  warn_renamed_fn("a5_get_threads", "a5_threads()")
  a5_threads()
}
