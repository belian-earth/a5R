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
    a5_abort("argument",
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
    a5_abort("argument", "{.arg {arg}} must be `TRUE` or `FALSE`.", call = call)
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
  new_a5_cell_list(rs)
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
    a5_abort("argument",
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
    a5_abort("resolution",
      "{.arg resolution} must be between {min} and {max}, not {resolution[which(bad)[1]]}.",
      call = call
    )
  }
  invisible(resolution)
}

#' Cast and validate a scalar, non-missing resolution
#'
#' `min = -1L` admits the world cell's resolution.
#' @noRd
check_scalar_resolution <- function(resolution, min = 0L,
                                    arg = rlang::caller_arg(resolution),
                                    call = rlang::caller_env()) {
  # Fast path for the common case, a bare whole number in range: base R
  # checks cost a fraction of a microsecond, vctrs and rlang several.
  if (
    is.numeric(resolution) && length(resolution) == 1L &&
      is.null(attributes(resolution)) && !is.na(resolution) &&
      resolution >= min && resolution <= 30 && resolution == trunc(resolution)
  ) {
    return(as.integer(resolution))
  }
  res <- vctrs::vec_cast(resolution, integer(), x_arg = arg, call = call)
  check_size1(res, arg = arg, call = call)
  if (is.na(res)) {
    a5_abort("resolution", "{.arg {arg}} must not be `NA`.", call = call)
  }
  if (res < min || res > 30L) {
    a5_abort("resolution", "{.arg {arg}} must be between {min} and 30, not {res}.", call = call)
  }
  res
}

#' Run a Rust call, re-raising its error from the user's call
#'
#' Rust errors surface as `Error in a5_xxx_rs(...)`, naming an internal
#' function. This re-raises them as if from `call`, the exported function,
#' with class `a5R_error` and, when given, `a5R_error_<type>`.
#' @noRd
from_caller <- function(expr, call, type = NULL) {
  tryCatch(expr, error = function(e) {
    msg <- conditionMessage(e)
    a5_abort(type, "{msg}", call = call)
  })
}

#' Raise an error a Rust call returned as an `a5R_rs_error` object
#'
#' Rust functions that map over cells return such an object, rather than
#' raising, when the a5 crate rejects a cell (see `FirstError` in
#' `cell_raw.rs`). Checking its class costs far less than a `tryCatch()`.
#' @noRd
check_rs <- function(out, call = rlang::caller_env()) {
  if (inherits(out, "a5R_rs_error")) {
    a5_abort("cell", "{out$message}", call = call)
  }
  out
}

#' Warn that an argument was renamed, and pass its value on
#' @noRd
renamed_arg <- function(value, old, new, call = rlang::caller_env()) {
  cli::cli_warn(
    "{.arg {old}} was renamed {.arg {new}} in a5R 1.0.0.",
    class = c("a5R_warning_deprecated", "a5R_warning"),
    call = call
  )
  value
}

#' Warn that a function was renamed
#' @noRd
warn_renamed_fn <- function(old, new, call = rlang::caller_env()) {
  cli::cli_warn(
    "{.fn {old}} was replaced by {.code {new}} in a5R 1.0.0.",
    class = c("a5R_warning_deprecated", "a5R_warning"),
    call = call
  )
}
