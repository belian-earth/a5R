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
  vctrs::vec_assert(n, size = 1L)
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
