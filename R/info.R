#' Cell area at a given resolution
#'
#' Returns the area of a single cell in square metres at the given
#' resolution(s). Because A5 is an equal-area DGGS, all cells at the same
#' resolution have identical area.
#'
#' @param resolution Integer vector of resolutions (0--30).
#' @returns A numeric vector of areas in square metres.
#'
#' @export
#' @examples
#' a5_cell_area(0:5)
a5_cell_area <- function(resolution) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  a5_cell_area_rs(resolution)
}

#' Total number of cells at a given resolution
#'
#' @param resolution Integer scalar resolution (0--30).
#' @returns A numeric scalar (double) giving the total count. Returned as
#'   double because the count can exceed R's integer range.
#'
#' @export
#' @examples
#' a5_get_num_cells(0)
#' a5_get_num_cells(10)
a5_get_num_cells <- function(resolution) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)
  a5_get_num_cells_rs(resolution)
}

#' Get all resolution-0 root cells
#'
#' Returns the 12 root cells corresponding to the 12 faces of the
#' dodecahedron.
#'
#' @returns An [a5_cell] vector of length 12.
#'
#' @export
#' @examples
#' a5_get_res0_cells()
a5_get_res0_cells <- function() {
  new_a5_cell(a5_get_res0_cells_rs())
}
