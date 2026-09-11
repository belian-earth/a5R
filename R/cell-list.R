#' List of A5 cell vectors
#'
#' `a5_cell_to_children()`, `a5_grid_disk()` and `a5_spherical_cap()` return
#' an `a5_cell_list` when called with `simplify = FALSE`: a
#' [vctrs::list_of()] holding one [a5_cell] vector per input, usable as a
#' list column. It behaves as any list: `lengths()` gives the number of cells
#' per input, `[[` extracts one element, and `tidyr::unnest()` expands it to
#' one row per cell.
#'
#' `unlist()` concatenates the elements into a single [a5_cell] vector,
#' equivalent to [vctrs::list_unchop()]. Without this method base
#' `unlist()` would descend into the raw byte fields of the record and return
#' a meaningless raw vector. The `recursive` and `use.names` arguments are
#' accepted for compatibility and ignored.
#'
#' `as_a5_cell_list()` wraps a plain list of [a5_cell] vectors (for example
#' the output of `lapply()`) so that `unlist()` works on it. Elements that
#' are hex strings are converted; `NULL` elements become empty.
#'
#' @param x An `a5_cell_list`, or for `as_a5_cell_list()` a list of
#'   [a5_cell] vectors.
#' @param recursive,use.names Ignored.
#' @returns `unlist()` returns an [a5_cell] vector.
#' @name a5_cell_list
#' @examples
#' cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
#' lst <- a5_cell_to_children(cells, simplify = FALSE)
#' lengths(lst)
#' unlist(lst)
NULL

#' @rdname a5_cell_list
#' @export
#' @examples
#'
#' # lapply() produces a plain list, on which base unlist() would return raw
#' # bytes; wrap it first.
#' plain <- lapply(seq_along(cells), function(i) a5_cell_to_children(cells[i]))
#' unlist(as_a5_cell_list(plain))
as_a5_cell_list <- function(x) {
  if (inherits(x, "a5_cell_list")) {
    return(x)
  }
  if (!is.list(x) || inherits(x, "a5_cell")) {
    cli::cli_abort("{.arg x} must be a list of {.cls a5_cell} vectors.")
  }
  new_a5_cell_list(lapply(x, function(el) {
    if (is.null(el)) new_a5_cell() else as_a5_cell(el)
  }))
}

#' @rdname a5_cell_list
#' @exportS3Method base::unlist
unlist.a5_cell_list <- function(x, recursive = TRUE, use.names = TRUE) {
  vctrs::list_unchop(x, ptype = a5_cell_ptype())
}

#' @exportS3Method vctrs::vec_ptype_abbr
vec_ptype_abbr.a5_cell_list <- function(x, ...) {
  "list<a5_cell>"
}

#' Wrap Rust-built a5_cell elements as an a5_cell_list
#'
#' Identical to `vctrs::new_list_of(x, ptype = new_a5_cell(), class =
#' "a5_cell_list")`; the elements are already a5_cell objects, and building
#' the prototype and validating the list cost about 45 µs per call.
#' @noRd
new_a5_cell_list <- function(x) {
  structure(
    x,
    ptype = a5_cell_ptype(),
    class = c("a5_cell_list", "vctrs_list_of", "vctrs_vctr", "list")
  )
}
