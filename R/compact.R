#' Compact a set of A5 cells
#'
#' Merges complete sibling groups into their common parent, reducing the
#' number of cells while preserving coverage.
#'
#' @param cells An [a5_cell] vector.
#' @returns An [a5_cell] vector of compacted cells.
#'
#' @seealso [a5_uncompact()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' children <- a5_cell_to_children(cell)
#' a5_compact(children) # back to the parent
a5_compact <- function(cells) {
  cells <- as_a5_cell(cells)
  out <- a5_compact_rs(vctrs::vec_data(cells))
  new_a5_cell(out)
}

#' Uncompact a set of A5 cells to a target resolution
#'
#' Expands each cell to its descendants at the target resolution.
#'
#' @param cells An [a5_cell] vector.
#' @param resolution Integer scalar target resolution (0--30).
#' @returns An [a5_cell] vector of uncompacted cells.
#'
#' @seealso [a5_compact()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_uncompact(cell, resolution = 7)
a5_uncompact <- function(cells, resolution) {
  cells <- as_a5_cell(cells)
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)
  out <- a5_uncompact_rs(vctrs::vec_data(cells), resolution)
  new_a5_cell(out)
}
