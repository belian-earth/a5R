#' Combine coverings
#'
#' Set operations on [a5_covering] vectors, computed on the compacted cells
#' without expanding them, so they stay fast for coverings that stand for
#' billions of cells:
#'
#' * `a5_union()`: cells in either covering. With `y` omitted, the union of
#'   every covering in `x`, as one covering: for example the coverings of all
#'   features from [a5_polygon_to_cells()].
#' * `a5_intersect()`: cells in both coverings.
#' * `a5_difference()`: cells in `x` but not in `y`.
#'
#' The operations work element by element, recycling a length-one argument,
#' so `a5_intersect(countries, cap)` intersects every country with one cap.
#' Both coverings of a pair must be at the same resolution: A5 cells do not
#' nest geometrically across resolutions, so combining sets at different
#' resolutions has no meaning, and it is an error. An empty covering with no
#' recorded resolution, as `a5_compact()` returns for no cells, combines with
#' any covering as the empty set.
#'
#' @param x,y [a5_covering] vectors, or objects `as_a5_covering()` accepts.
#'   Sizes must be compatible under vctrs recycling rules.
#' @returns An [a5_covering] vector of the common size of `x` and `y` (size
#'   one for `a5_union(x)`). `NA` where either input is `NA`; `a5_union(x)`
#'   skips `NA` elements.
#'
#' @seealso [a5_contains()], [a5_overlaps()] and [a5_count()] to query
#'   coverings.
#' @name a5_set_operations
#' @examples
#' edinburgh <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 12)
#' glasgow <- a5_lonlat_to_cell(-4.25, 55.86, resolution = 12)
#' caps <- a5_spherical_cap(c(edinburgh, glasgow), radius = 40000)
#'
#' a5_union(caps[1], caps[2])
#' a5_intersect(caps[1], caps[2])
#' a5_difference(caps[1], caps[2])
#'
#' # the union of every element
#' a5_union(caps)
NULL

#' @rdname a5_set_operations
#' @export
a5_union <- function(x, y = NULL) {
  x <- as_a5_covering(x)
  if (is.null(y)) {
    return(coverings_from_rs(a5_covering_union_all_rs(x)))
  }
  covering_set_op(x, y, "union")
}

#' @rdname a5_set_operations
#' @export
a5_intersect <- function(x, y) {
  covering_set_op(as_a5_covering(x), y, "intersect")
}

#' @rdname a5_set_operations
#' @export
a5_difference <- function(x, y) {
  covering_set_op(as_a5_covering(x), y, "difference")
}

covering_set_op <- function(x, y, op, call = rlang::caller_env()) {
  y <- as_a5_covering(y)
  vctrs::vec_size_common(x = x, y = y, .call = call)
  coverings_from_rs(a5_covering_set_op_rs(x, y, op))
}

#' Test coverings
#'
#' `a5_contains()` tests whether each cell is in a covering, and
#' `a5_overlaps()` whether two coverings share any cell. Both work on the
#' compacted cells, without expanding them, and element by element,
#' recycling a length-one argument.
#'
#' `a5_contains()` is a point-in-polygon test once the point is indexed at
#' the covering's resolution:
#' `a5_contains(covering, a5_lonlat_to_cell(lon, lat, a5_covering_resolution(covering)))`.
#' The cell must be at the covering's resolution, or it is an error: A5 cells
#' do not nest geometrically, so a finer cell is not guaranteed to lie inside
#' the coarser cell that holds it in the index. An empty covering contains no
#' cell.
#'
#' @param x An [a5_covering] vector, or an object `as_a5_covering()`
#'   accepts.
#' @param cell An [a5_cell] vector, each at the resolution of its covering.
#' @param y An [a5_covering] vector, at the same resolution as `x`.
#' @returns A logical vector of the common size of the inputs. `NA` where
#'   either input is `NA`.
#'
#' @seealso [a5_set_operations].
#' @name a5_covering_predicates
#' @examples
#' poly <- wk::wkt("POLYGON ((-3.4 55.85, -3 55.85, -3 56.05, -3.4 56.05, -3.4 55.85))")
#' edinburgh <- a5_polygon_to_cells(poly, resolution = 12)
#'
#' # point in polygon, at the covering's resolution
#' points <- a5_lonlat_to_cell(c(-3.19, -4.25), c(55.95, 55.86), resolution = 12)
#' a5_contains(edinburgh, points)
#'
#' cap <- a5_spherical_cap(points, radius = 5000)
#' a5_overlaps(edinburgh, cap)
NULL

#' @rdname a5_covering_predicates
#' @export
a5_contains <- function(x, cell) {
  x <- as_a5_covering(x)
  cell <- as_a5_cell(cell)
  vctrs::vec_size_common(x = x, cell = cell)
  a5_covering_contains_rs(x, cell_data(cell))
}

#' @rdname a5_covering_predicates
#' @export
a5_overlaps <- function(x, y) {
  x <- as_a5_covering(x)
  y <- as_a5_covering(y)
  vctrs::vec_size_common(x = x, y = y)
  a5_covering_overlaps_rs(x, y)
}

#' Measure coverings
#'
#' `a5_count()` returns the number of cells each covering stands for at its
#' resolution: the length of its [a5_uncompact()] result, without building
#' it. This differs from the number of cells stored. `a5_area()` returns
#' the area of each covering. A5 cells are equal-area, so this is exact up to
#' rounding: the count times [a5_cell_area()] at the covering's resolution.
#'
#' Counts are doubles, exact up to 2^53 (about 9e15 cells); coverings at the
#' finest resolutions can stand for more, and those counts are rounded.
#'
#' @param x An [a5_covering] vector, or an object `as_a5_covering()`
#'   accepts.
#' @param units Character scalar area unit for `a5_area()` (default
#'   `"m^2"`). Any unit [units::set_units()] can convert to is accepted (e.g.
#'   `"km^2"`, `"ha"`). If `NULL`, a plain numeric vector in square metres.
#' @returns `a5_count()`: a numeric vector the length of `x`. `a5_area()`: a
#'   [units::units] vector the length of `x`, or numeric when `units = NULL`.
#'   `NA` for a missing covering.
#'
#' @seealso [a5_cell_area()] for the area of a single cell.
#' @name a5_covering_measures
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 12)
#' cap <- a5_spherical_cap(cell, radius = 10000)
#' cap
#' a5_count(cap)
#' a5_area(cap, units = "km^2")
NULL

#' @rdname a5_covering_measures
#' @export
a5_count <- function(x) {
  x <- as_a5_covering(x)
  a5_covering_summary_rs(x)$count
}

#' @rdname a5_covering_measures
#' @export
a5_area <- function(x, units = "m^2") {
  x <- as_a5_covering(x)
  check_units(units, "m^2", "an area unit")
  with_units(a5_covering_area_rs(x), "m^2", units)
}
