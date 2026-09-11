#' Cell area at a given resolution
#'
#' Returns the area of a single cell in square metres at the given
#' resolution(s). Because A5 is an equal-area DGGS, all cells at the same
#' resolution have identical area.
#'
#' @param resolution Integer vector of resolutions (0--30).
#' @param units Character scalar specifying the output area unit (default
#'   `"m^2"`). Any unit convertible from `m^2` via [units::set_units()] is
#'   accepted (e.g. `"km^2"`, `"ha"`, `"acre"`).  If NULL, the area is
#'   returned as a numeric vector in m^2.
#' @returns A [units::units] vector of areas.
#'
#' @export
#' @examples
#' a5_cell_area(0:5)
#' a5_cell_area(5, units = "km^2")
a5_cell_area <- function(resolution, units = "m^2") {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_units(units, "m^2", "an area unit")
  with_units(a5_cell_area_rs(resolution), "m^2", units)
}

#' Average cell edge length at a given resolution
#'
#' Returns the average length of a cell edge at the given resolution(s).
#' Individual edge lengths vary from this average by roughly +/-10%,
#' depending on the cell's shape and its position on the globe. Use this
#' for a quick estimate of cell size when choosing a resolution; use
#' [a5_cell_to_boundary()] to measure a specific cell.
#'
#' @param resolution Integer vector of resolutions (0--30).
#' @param units Character scalar specifying the output length unit
#'   (default `"m"`). Any unit convertible from `m` via
#'   [units::set_units()] is accepted (e.g. `"km"`, `"mi"`). If NULL, the
#'   length is returned as a numeric vector in metres.
#' @returns A [units::units] vector of average edge lengths, or a numeric
#'   vector if `units = NULL`.
#'
#' @seealso [a5_cell_area()]
#' @export
#' @examples
#' a5_cell_edge_length_avg(0:5)
#' a5_cell_edge_length_avg(10, units = "km")
a5_cell_edge_length_avg <- function(resolution, units = "m") {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_units(units, "m", "a length unit")
  with_units(a5_cell_edge_length_avg_rs(resolution), "m", units)
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
  check_size1(resolution)
  a5_get_num_cells_rs(resolution)
}

#' Number of children between two resolutions
#'
#' Returns the number of child cells each parent cell contains when
#' expanding from one resolution to another.
#'
#' @param parent_resolution Integer scalar (0--30).
#' @param child_resolution Integer scalar (0--30), must be >=
#'   `parent_resolution`.
#' @returns A numeric scalar. Returned as double because the count can
#'   exceed R's integer range at large resolution deltas.
#'
#' @seealso [a5_get_num_cells()], [a5_cell_to_children()],
#'   [a5_uncompact()]
#' @export
#' @examples
#' a5_get_num_children(5, 8)   # 4^3 = 64
#' a5_get_num_children(0, 5)
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
