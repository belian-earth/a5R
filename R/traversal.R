#' Cells within k hops of a cell
#'
#' Returns all cells reachable within `k` edge hops of a centre cell,
#' including the centre cell itself.
#'
#' @param cell A single [a5_cell] value.
#' @param k Integer scalar, number of hops.
#' @param vertex Logical scalar. If `FALSE` (default), only edge-sharing
#'   neighbours (4-connected) are traversed. If `TRUE`, vertex-sharing
#'   neighbours are included (8-connected).
#' @returns A compacted [a5_cell] vector.
#'
#' @seealso [a5_spherical_cap()] for distance-based selection.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' a5_grid_disk(cell, k = 1)
a5_grid_disk <- function(cell, k, vertex = FALSE) {
  cell <- as_a5_cell(cell)
  vctrs::vec_assert(cell, size = 1L)
  k <- vctrs::vec_cast(k, integer())
  vctrs::vec_assert(k, size = 1L)
  out <- a5_grid_disk_rs(vctrs::vec_data(cell)[[1]], k, vertex)
  new_a5_cell(out)
}

#' Cells within a great-circle radius
#'
#' Returns all cells whose centres fall within a great-circle distance
#' of a given cell's centre.
#'
#' @param cell A single [a5_cell] value.
#' @param radius Numeric scalar, great-circle radius in metres.
#' @returns A compacted [a5_cell] vector.
#'
#' @seealso [a5_grid_disk()] for hop-based selection.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' a5_spherical_cap(cell, radius = 1000)
a5_spherical_cap <- function(cell, radius) {
  cell <- as_a5_cell(cell)
  vctrs::vec_assert(cell, size = 1L)
  radius <- vctrs::vec_cast(radius, double())
  vctrs::vec_assert(radius, size = 1L)
  out <- a5_spherical_cap_rs(vctrs::vec_data(cell)[[1]], radius)
  new_a5_cell(out)
}
