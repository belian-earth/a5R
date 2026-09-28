#' Cell size and counts by resolution
#'
#' Properties of the grid at a resolution, independent of any particular
#' cell:
#'
#' * `a5_cell_area()`: the area of one cell. A5 is an equal-area grid, so
#'   every cell at a resolution has the same area.
#' * `a5_cell_edge_length_avg()`: the average cell edge length. Individual
#'   edges vary from this by roughly +/-10%, depending on the cell's shape
#'   and position; use [a5_cell_to_boundary()] to measure a specific cell.
#' * `a5_get_num_cells()`: the number of cells covering the globe.
#' * `a5_get_num_children()`: the number of descendants each cell has at a
#'   finer resolution, as returned by [a5_cell_to_children()].
#'
#' Use the first two to choose a resolution for a target cell size.
#'
#' @param resolution Integer vector of resolutions (0--30). A scalar for
#'   `a5_get_num_cells()`.
#' @param units Character scalar giving the output unit: an area unit for
#'   `a5_cell_area()` (default `"m^2"`), a length unit for
#'   `a5_cell_edge_length_avg()` (default `"m"`). Any unit
#'   [units::set_units()] can convert to is accepted (e.g. `"km^2"`, `"ha"`,
#'   `"km"`, `"mi"`). If `NULL`, a plain numeric vector in square metres or
#'   metres is returned.
#' @param parent_resolution,child_resolution Integer scalars (0--30), with
#'   `child_resolution` at or finer than `parent_resolution`.
#' @returns
#' * `a5_cell_area()`, `a5_cell_edge_length_avg()`: a [units::units] vector
#'   the length of `resolution`, or numeric when `units = NULL`.
#' * `a5_get_num_cells()`, `a5_get_num_children()`: a numeric scalar. Counts
#'   are doubles because they can exceed R's integer range.
#'
#' @name a5_resolution_stats
#' @examples
#' a5_cell_area(0:5)
#' a5_cell_area(5, units = "km^2")
#' a5_cell_edge_length_avg(10, units = "km")
#'
#' a5_get_num_cells(10)
#' a5_get_num_children(5, 8) # 4^3 = 64
#'
#' # cells at a resolution times their area covers the globe
#' a5_get_num_cells(10) * a5_cell_area(10, units = "km^2")
NULL

#' @rdname a5_resolution_stats
#' @export
a5_cell_area <- function(resolution, units = "m^2") {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_units(units, "m^2", "an area unit")
  with_units(a5_cell_area_rs(resolution), "m^2", units)
}

#' @rdname a5_resolution_stats
#' @export
a5_cell_edge_length_avg <- function(resolution, units = "m") {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_units(units, "m", "a length unit")
  with_units(a5_cell_edge_length_avg_rs(resolution), "m", units)
}

#' @rdname a5_resolution_stats
#' @export
a5_get_num_cells <- function(resolution) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_size1(resolution)
  a5_get_num_cells_rs(resolution)
}

#' @rdname a5_resolution_stats
#' @export
a5_get_num_children <- function(parent_resolution, child_resolution) {
  parent_resolution <- vctrs::vec_cast(parent_resolution, integer())
  child_resolution <- vctrs::vec_cast(child_resolution, integer())
  check_resolution(parent_resolution)
  check_resolution(child_resolution)
  check_size1(parent_resolution)
  check_size1(child_resolution)
  a5_get_num_children_rs(parent_resolution, child_resolution)
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
  cells_from_rs(a5_get_res0_cells_rs())
}
