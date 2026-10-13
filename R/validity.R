#' Check that values are A5 cells
#'
#' `a5_is_valid_cell()` checks each value against the A5 index encoding: its
#' resolution bits must name a resolution, and its face or quintant must
#' exist. Use it on ids from outside sources, such as a file or a database,
#' before passing them to other functions. [a5_cell()] accepts any 16-digit
#' hex string, so an `a5_cell` vector can hold values that are not cells.
#'
#' `a5_is_valid()` checks any a5R object, returning one value per element:
#'
#' * an [a5_cell] vector or hex strings: whether each value is a cell, as
#'   `a5_is_valid_cell()`.
#' * an [a5_cell_list]: whether every cell in each element is valid. An empty
#'   element is valid.
#' * an [a5_covering]: whether each covering is well formed: every stored
#'   value but a trailing compaction marker is a valid cell, no cell is finer
#'   than the covering's resolution, and the cells are sorted in curve order
#'   without overlapping. a5R always builds coverings this way; the check is
#'   for coverings assembled by hand, as the covering functions rely on it.
#'   A covering need not be fully compacted to be valid.
#'
#' The world cell (id 0, resolution -1) is valid: it has no boundary, but
#' [a5_cell_to_parent()] returns it as the parent of the resolution-0 cells.
#' Validity says nothing about which index version an id was written with:
#' ids from a5R before 1.0 are valid cells in a different place. See
#' [a5_migrate()].
#'
#' @param x An [a5_cell] vector or a character vector of hex strings. For
#'   `a5_is_valid()`, also an [a5_cell_list] or an [a5_covering].
#' @returns A logical vector the length of `x`. `NA` where `x` is `NA`; for
#'   an [a5_cell_list], `NA` where an element holds `NA` and no invalid cell;
#'   for an [a5_covering], `NA` for a missing covering.
#'   Hex strings that are not 16 hex digits are `FALSE`.
#'
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
#' a5_is_valid_cell(cell)
#' a5_is_valid_cell(c(a5_u64_to_hex(cell), "fd00000000000000", "not_a_cell", NA))
#'
#' a5_is_valid(a5_cell_to_children(cell, simplify = FALSE))
a5_is_valid <- function(x) {
  UseMethod("a5_is_valid")
}

#' @rdname a5_is_valid
#' @export
a5_is_valid_cell <- function(x) {
  if (is_a5_cell(x)) {
    return(a5_is_valid_cell_rs(cell_data(x)))
  }
  a5_is_valid_hex_rs(vctrs::vec_cast(x, character()))
}

#' @export
a5_is_valid.default <- function(x) {
  a5_is_valid_cell(x)
}

#' @export
a5_is_valid.a5_cell_list <- function(x) {
  valid <- a5_is_valid_cell(unlist(x))
  element <- rep.int(seq_along(x), lengths(x))
  out <- rep(TRUE, length(x))
  out[element[is.na(valid)]] <- NA
  out[element[valid %in% FALSE]] <- FALSE
  out
}

#' @export
a5_is_valid.a5_covering <- function(x) {
  a5_is_valid_covering_rs(x)
}
