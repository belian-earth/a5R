#' Set the number of threads used by a5R
#'
#' Controls the number of threads used for parallel processing in vectorised
#' functions. Set to 1 (the default) for sequential processing with zero
#' overhead, or higher for parallel execution via rayon.
#'
#' @param n Integer scalar. Number of threads. Must be >= 1.
#' @returns Invisibly returns the previous thread count.
#' @rdname a5_threads
#' @export
a5_set_threads <- function(n = 1L) {
  n <- vctrs::vec_cast(n, integer())
  check_size1(n)
  if (is.na(n) || n < 1L) {
    a5_abort("argument", "{.arg n} must be a positive integer, not {n}.")
  }
  old <- a5_get_threads_rs()
  a5_set_threads_rs(n)
  invisible(old)
}

#' Get the current number of threads
#'
#' @rdname a5_threads
#' @returns Integer scalar.
#' @export
a5_get_threads <- function() {
  a5_get_threads_rs()
}

#' Use a number of threads temporarily
#'
#' `with_a5_threads()` runs `code` with `n` threads and restores the previous
#' count afterwards, even on error. `local_a5_threads()` sets `n` threads
#' until the calling function, or `.local_envir`, exits.
#'
#' @param n Integer scalar. Number of threads, at least 1.
#' @param code Code to run.
#' @param .local_envir The environment whose exit restores the thread count.
#' @returns `with_a5_threads()`: the value of `code`. `local_a5_threads()`:
#'   the previous thread count, invisibly.
#' @seealso [a5_set_threads()]
#' @export
#' @examples
#' cells <- a5_lonlat_to_cell(runif(1000, -180, 180), runif(1000, -80, 80), 10)
#' b <- with_a5_threads(2, a5_cell_to_boundary(cells))
#' a5_get_threads()
#'
#' f <- function() {
#'   local_a5_threads(2)
#'   a5_get_threads()
#' }
#' f()
#' a5_get_threads()
with_a5_threads <- function(n, code) {
  old <- a5_set_threads(n)
  on.exit(a5_set_threads(old), add = TRUE)
  force(code)
}

#' @rdname with_a5_threads
#' @export
local_a5_threads <- function(n, .local_envir = parent.frame()) {
  old <- a5_set_threads(n)
  do.call(on.exit, list(call("a5_set_threads", old), add = TRUE), envir = .local_envir)
  invisible(old)
}
