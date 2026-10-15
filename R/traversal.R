#' Cells within k hops of a cell
#'
#' Returns, for each centre cell, the cells reachable within `k` hops,
#' including the centre cell itself, as an [a5_covering].
#'
#' @param cell An [a5_cell] vector of centre cells.
#' @param k Non-negative integer scalar, number of hops.
#' @param vertex Logical scalar. If `FALSE` (default), only edge-sharing
#'   neighbours are traversed. If `TRUE`, vertex-sharing neighbours are
#'   included too.
#' @returns An [a5_covering] vector the same length as `cell`, at the
#'   resolution of each centre cell. `NA` where `cell` is `NA`. Use
#'   [a5_uncompact()] for the cells.
#'
#' @seealso [a5_spherical_cap()] for distance-based selection.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' disk <- a5_grid_disk(cell, k = 1)
#' disk
#' a5_uncompact(disk)
#'
#' cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
#' a5_grid_disk(cells, k = 2) # one covering per cell
a5_grid_disk <- function(cell, k, vertex = FALSE) {
  cell <- as_a5_cell(cell)
  k <- vctrs::vec_cast(k, integer())
  check_size1(k)
  if (is.na(k) || k < 0L) {
    cli::cli_abort("{.arg k} must be a non-negative integer, not {k}.")
  }
  check_flag(vertex)
  coverings_from_rs(a5_grid_disk_rs(cell_data(cell), k, vertex))
}

#' Cells within a great-circle radius
#'
#' Returns, for each centre cell, the cells whose centres fall within a
#' great-circle distance of its centre, as an [a5_covering].
#'
#' @param cell An [a5_cell] vector of centre cells.
#' @param radius Non-negative numeric scalar, great-circle radius in metres.
#'   It is measured on the sphere A5 uses internally, so membership can
#'   differ by a fraction of a percent of `radius` from distances given by
#'   [a5_cell_distance()].
#' @returns An [a5_covering] vector the same length as `cell`, at the
#'   resolution of each centre cell. `NA` where `cell` is `NA`. Use
#'   [a5_uncompact()] for the cells.
#'
#' @seealso [a5_grid_disk()] for hop-based selection.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' cap <- a5_spherical_cap(cell, radius = 1000)
#' cap
#' a5_uncompact(cap)
a5_spherical_cap <- function(cell, radius) {
  cell <- as_a5_cell(cell)
  radius <- vctrs::vec_cast(radius, double())
  check_size1(radius)
  if (!is.finite(radius) || radius < 0) {
    cli::cli_abort("{.arg radius} must be a finite, non-negative number, not {radius}.")
  }
  coverings_from_rs(a5_spherical_cap_rs(cell_data(cell), radius))
}
