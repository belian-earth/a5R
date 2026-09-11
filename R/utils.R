#' @importFrom rlang caller_env
#' @importFrom vctrs vec_cast vec_ptype2
NULL

#' Assert that `x` has length one
#'
#' Equivalent to `check_size1(x)` for atomic vectors and
#' `a5_cell` records, at a fraction of the cost. `arg` and `call` are only
#' evaluated on failure.
#' @noRd
check_size1 <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (length(x) != 1L) {
    cli::cli_abort(
      "{.arg {arg}} must have size 1, not size {length(x)}.",
      call = call
    )
  }
  invisible(x)
}

#' Attach units to a numeric vector
#'
#' `base` is the unit the Rust side reports in (`"m"` or `"m^2"`). The parsed
#' `units` attribute for each base unit is cached on first use, so the common
#' case of returning the base unit costs one `structure()` call rather than a
#' udunits parse. Other units go through `units::set_units()` as before.
#' @noRd
with_units <- function(x, base, units) {
  if (is.null(units)) {
    return(x)
  }
  x <- structure(x, units = base_units_attr(base), class = "units")
  if (identical(units, base)) {
    return(x)
  }
  units::set_units(x, units, mode = "standard")
}

the_units_cache <- new.env(parent = emptyenv())

base_units_attr <- function(base) {
  cached <- the_units_cache[[base]]
  if (is.null(cached)) {
    cached <- attr(units::set_units(1, base, mode = "standard"), "units")
    assign(base, cached, envir = the_units_cache)
  }
  cached
}

#' Validate a `units` argument against a base unit
#' @noRd
check_units <- function(units, base, what, call = rlang::caller_env()) {
  if (
    !is.null(units) && !identical(units, base) &&
      !units::ud_are_convertible(base, units)
  ) {
    cli::cli_abort(
      "{.arg units} must be {what} convertible from {base} (or NULL), not {.val {units}}.",
      call = call
    )
  }
  invisible(units)
}

check_resolution <- function(resolution,
                             min = 0L,
                             max = 30L,
                             call = rlang::caller_env()) {
  bad <- !is.na(resolution) & (resolution < min | resolution > max)
  if (any(bad)) {
    cli::cli_abort(
      "{.arg resolution} must be between {min} and {max}, not {resolution[which(bad)[1]]}.",
      call = call
    )
  }
  invisible(resolution)
}
