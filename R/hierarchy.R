#' Get the resolution of A5 cell indices
#'
#' Extracts the resolution level (0--30) encoded in each cell index.
#'
#' @param cell An [a5_cell] vector.
#' @returns An integer vector of resolutions.
#'
#' @seealso [a5_cell_to_parent()], [a5_cell_to_children()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
#' a5_get_resolution(cell)
a5_get_resolution <- function(cell) {
  cell <- as_a5_cell(cell)
  a5_get_resolution_rs(vctrs::field(cell, "hi"), vctrs::field(cell, "lo"))
}

#' Navigate to parent cell(s)
#'
#' Returns the parent cell of each input cell. By default returns the
#' immediate parent (one resolution coarser). Optionally target a specific
#' coarser resolution.
#'
#' @param cell An [a5_cell] vector.
#' @param resolution Integer scalar target parent resolution, or `NULL` for
#'   the immediate parent.
#' @returns An [a5_cell] vector of parent cells.
#'
#' @seealso [a5_cell_to_children()], [a5_get_resolution()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
#' a5_cell_to_parent(cell)
#' a5_cell_to_parent(cell, resolution = 5)
a5_cell_to_parent <- function(cell, resolution = NULL) {
  cell <- as_a5_cell(cell)
  if (!is.null(resolution)) {
    resolution <- vctrs::vec_cast(resolution, integer())
    check_resolution(resolution)
    vctrs::vec_assert(resolution, size = 1L)
  }
  cells_from_rs(a5_cell_to_parent_rs(
    vctrs::field(cell, "hi"), vctrs::field(cell, "lo"), resolution
  ))
}

#' Get child cells
#'
#' Returns the child cells of a single cell. By default returns the 4
#' immediate children (one resolution finer). Optionally target a specific
#' finer resolution.
#'
#' @param cell A single [a5_cell] value.
#' @param resolution Integer scalar target child resolution, or `NULL` for
#'   immediate children.
#' @returns An [a5_cell] vector of child cells.
#'
#' @seealso [a5_cell_to_parent()], [a5_get_resolution()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_children(cell)
a5_cell_to_children <- function(cell, resolution = NULL) {
  cell <- as_a5_cell(cell)
  vctrs::vec_assert(cell, size = 1L)
  if (!is.null(resolution)) {
    resolution <- vctrs::vec_cast(resolution, integer())
    check_resolution(resolution)
    vctrs::vec_assert(resolution, size = 1L)
  }
  cells_from_rs(a5_cell_to_children_rs(
    vctrs::field(cell, "hi"), vctrs::field(cell, "lo"), resolution
  ))
}
