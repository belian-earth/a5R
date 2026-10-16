#' Cells within k hops of a cell
#'
#' Returns, for each centre cell, the cells reachable within `k` hops,
#' including the centre cell itself, as an [a5_covering].
#' `a5_grid_disk()` steps between cells that share an edge;
#' `a5_grid_disk_vertex()` also steps between cells that share only a
#' vertex, so it reaches more cells for the same `k`.
#'
#' @param cell An [a5_cell] vector of centre cells.
#' @param k Non-negative integer scalar, number of hops.
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
#' a5_grid_disk_vertex(cell, k = 1)
#'
#' cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
#' a5_grid_disk(cells, k = 2) # one covering per cell
a5_grid_disk <- function(cell, k) {
  cell <- as_a5_cell(cell)
  coverings_from_rs(a5_grid_disk_rs(cell_data(cell), check_hops(k)))
}

#' @rdname a5_grid_disk
#' @export
a5_grid_disk_vertex <- function(cell, k) {
  cell <- as_a5_cell(cell)
  coverings_from_rs(a5_grid_disk_vertex_rs(cell_data(cell), check_hops(k)))
}

check_hops <- function(k, call = rlang::caller_env()) {
  k <- vctrs::vec_cast(k, integer(), call = call)
  check_size1(k, call = call)
  if (is.na(k) || k < 0L) {
    a5_abort("argument", "{.arg k} must be a non-negative integer, not {k}.", call = call)
  }
  k
}

#' Cells within a great-circle radius
#'
#' Returns, for each centre cell, the cells whose centres fall within a
#' great-circle distance of its centre, as an [a5_covering].
#'
#' @param cell An [a5_cell] vector of centre cells.
#' @param radius Non-negative numeric scalar, great-circle radius in `units`,
#'   or a [units][units::units] object of length. It is measured on the sphere A5 uses internally, so membership can
#'   differ by a fraction of a percent of `radius` from distances given by
#'   [a5_cell_distance()].
#' @param units Character scalar, the length unit of a plain numeric
#'   `radius`: `"m"` (the default) or any unit convertible from metres, such
#'   as `"km"`.
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
a5_spherical_cap <- function(cell, radius, units = "m") {
  cell <- as_a5_cell(cell)
  if (inherits(radius, "units")) {
    radius <- as.numeric(units::set_units(radius, "m", mode = "standard"))
  } else {
    check_units(units, "m", "a length unit")
    radius <- vctrs::vec_cast(radius, double())
    if (!is.null(units) && !identical(units, "m")) {
      radius <- as.numeric(units::set_units(units::set_units(radius, units, mode = "standard"), "m", mode = "standard"))
    }
  }
  check_size1(radius)
  if (!is.finite(radius) || radius < 0) {
    a5_abort("argument", "{.arg radius} must be a finite, non-negative number, not {radius}.")
  }
  coverings_from_rs(a5_spherical_cap_rs(cell_data(cell), radius))
}
