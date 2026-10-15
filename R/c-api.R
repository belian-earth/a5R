#' C API for other packages
#'
#' Packages that produce or consume cells in compiled code can convert
#' between 64-bit ids and [a5_cell] vectors through a5R's C API, without
#' depending on how `a5_cell` stores its data. Add `LinkingTo: a5R` and
#' `Imports: a5R` to the package's DESCRIPTION, then include `a5R.h`:
#'
#' ```c
#' #include <a5R.h>
#'
#' // ids to an a5_cell vector; is_na may be NULL
#' SEXP cells = PROTECT(a5R_cells_from_u64(ids, is_na, n));
#'
#' // an a5_cell vector to ids and NA flags; returns the length
#' R_xlen_t n = a5R_cells_to_u64(cells, ids, is_na);
#' ```
#'
#' `a5R_api_version()` returns the version of the API, currently 1. NA cells
#' are flagged in an `int` array, as in an R logical vector, rather than
#' encoded in the id. Packages written in Rust can call the same functions
#' through `R_GetCCallable("a5R", "a5R_cells_from_u64")` and its siblings;
#' the signatures are in `system.file("include", "a5R.h", package = "a5R")`.
#'
#' @name a5_c_api
#' @keywords internal
NULL
