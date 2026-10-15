#' Set the number of threads used by a5R
#'
#' Controls the number of threads used for parallel processing in vectorised
#' functions. Set to 1 (the default) for sequential processing with zero
#' overhead, or higher for parallel execution via rayon.
#'
#' `a5_set_threads()` returns the previous thread count, so a change can be
#' scoped to a block of code with [with()], as `mirai::daemons()` is:
#' `with(a5_set_threads(4), expr)` runs `expr` on four threads and then
#' restores the previous count, even if `expr` fails.
#'
#' @param n Integer scalar. Number of threads. Must be >= 1. The value
#'   returned by an earlier `a5_set_threads()` call also works.
#' @param data The value of `a5_set_threads()`.
#' @param expr Code to run with that thread count.
#' @param ... Unused.
#' @returns `a5_set_threads()`: the previous thread count, invisibly, as an
#'   `a5_threads` object. `with()`: the value of `expr`. `a5_get_threads()`:
#'   the current count, an integer scalar.
#' @rdname a5_threads
#' @export
#' @examples
#' cells <- a5_lonlat_to_cell(runif(1000, -180, 180), runif(1000, -80, 80), 10)
#' b <- with(a5_set_threads(2), a5_cell_to_boundary(cells))
#' a5_get_threads()
a5_set_threads <- function(n = 1L) {
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
  on.exit(a5_set_threads(data), add = TRUE)
  expr
}

#' @export
print.a5_threads <- function(x, ...) {
  cat("<a5_threads> previous count:", as.integer(x), "\n")
  invisible(x)
}

#' @rdname a5_threads
#' @export
a5_get_threads <- function() {
  a5_get_threads_rs()
}
