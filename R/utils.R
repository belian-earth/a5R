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

#' Assert that `x` is `TRUE` or `FALSE`
#' @noRd
check_flag <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be `TRUE` or `FALSE`.", call = call)
  }
  invisible(x)
}

#' Shape the result of a one-to-many Rust call
#'
#' With `simplify = TRUE` the Rust side returns one concatenated b1..b8 list;
#' otherwise it returns a list of fully formed `a5_cell` objects, one per
#' input (empty for `NA` inputs), which only needs the `list_of` wrapper.
#' @noRd
one_to_many <- function(rs, simplify) {
  if (simplify) {
    return(cells_from_rs(rs))
  }
  # Identical to vctrs::new_list_of(rs, ptype = new_a5_cell()); the elements
  # are already a5_cell objects, and building the prototype and validating
  # the list cost about 45 µs per call.
  structure(
    rs,
    ptype = a5_cell_ptype(),
    class = c("vctrs_list_of", "vctrs_vctr", "list")
  )
}

the_ptype_cache <- new.env(parent = emptyenv())

a5_cell_ptype <- function() {
  cached <- the_ptype_cache$a5_cell
  if (is.null(cached)) {
    cached <- new_a5_cell()
    assign("a5_cell", cached, envir = the_ptype_cache)
  }
  cached
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

#' Match a choice argument, short-circuiting the default
#'
#' `rlang::arg_match()` costs about 30 µs, mostly building its error
#' context. An untouched default is the full `choices` vector, which
#' `arg_match()` maps to its first element; that case is detected with
#' `identical()` instead. `missing()` cannot be used here because it does not
#' see through to a caller's formal that has a default. Errors still name the
#' caller's argument and call.
#' @noRd
arg_match_default <- function(arg, choices,
                              error_arg = rlang::caller_arg(arg),
                              error_call = rlang::caller_env()) {
  if (identical(arg, choices)) {
    return(choices[[1L]])
  }
  rlang::arg_match(arg, choices, error_arg = error_arg, error_call = error_call)
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
