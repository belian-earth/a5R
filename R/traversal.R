#' Cells within k hops of a cell
#'
#' Returns all cells reachable within `k` edge hops of a centre cell,
#' including the centre cell itself.
#'
#' @param cell An [a5_cell] vector of centre cells.
#' @param k Integer scalar, number of hops.
#' @param simplify Logical scalar. If `TRUE` (default), return one flat
#'   [a5_cell] vector with the disks of every input concatenated in input
#'   order; cells shared by several disks appear once per disk. If `FALSE`,
#'   return an [a5_cell_list]: a [vctrs::list_of()] of [a5_cell] vectors with
#'   one element per input, suitable for a list column.
#' @param vertex Logical scalar. If `FALSE` (default), only edge-sharing
#'   neighbours (4-connected) are traversed. If `TRUE`, vertex-sharing
#'   neighbours are included (8-connected).
#' @returns An [a5_cell] vector, or an [a5_cell_list] when `simplify = FALSE`.
#'   An `NA` input contributes no cells (an empty element in the list form).
#'
#' @seealso [a5_spherical_cap()] for distance-based selection.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' a5_grid_disk(cell, k = 1)
#'
#' cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
#' a5_grid_disk(cells, k = 1)                   # both disks, one vector
#' a5_grid_disk(cells, k = 1, simplify = FALSE) # list of 2
a5_grid_disk <- function(cell, k, vertex = FALSE, simplify = TRUE) {
  cell <- as_a5_cell(cell)
  k <- vctrs::vec_cast(k, integer())
  check_size1(k)
  check_flag(vertex)
  check_flag(simplify)
  one_to_many(a5_grid_disk_rs(cell_data(cell), k, vertex, simplify), simplify)
}

#' Cells within a great-circle radius
#'
#' Returns all cells whose centres fall within a great-circle distance
#' of a given cell's centre.
#'
#' @param cell A single [a5_cell] value.
#' @param radius Numeric scalar, great-circle radius in metres.
#' @returns An [a5_cell] vector, or an [a5_cell_list] when `simplify = FALSE`.
#'   An `NA` input contributes no cells (an empty element in the list form).
#'
#' @seealso [a5_grid_disk()] for hop-based selection.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' a5_spherical_cap(cell, radius = 1000)
a5_spherical_cap <- function(cell, radius, simplify = TRUE) {
  cell <- as_a5_cell(cell)
  radius <- vctrs::vec_cast(radius, double())
  check_size1(radius)
  check_flag(simplify)
  one_to_many(a5_spherical_cap_rs(cell_data(cell), radius, simplify), simplify)
}
