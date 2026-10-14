#' Get cell boundary polygons
#'
#' Returns the boundary of each cell as a [wk::wkt()] or [wk::wkb()]
#' polygon geometry. Boundaries are pentagonal polygons on the WGS 84
#' ellipsoid.
#'
#' @param cell An [a5_cell] vector.
#' @param format Character scalar, either `"wkb"` (default) or `"wkt"`.
#' @param closed Logical scalar; if `TRUE` (default) the ring is closed
#'   (first vertex repeated at end).
#' @param segments Integer scalar or `NULL`. Number of segments per cell
#'   edge. A5 cell edges are slightly curved on the sphere: a single segment
#'   between two vertices strays from the true edge by up to about 450 m at
#'   resolution 6, 25 m at resolution 8 and 1.5 m at resolution 10. The
#'   error falls with the square of the number of segments. `NULL` uses the
#'   A5 default of `max(1, 2^(6 - resolution))`, so at resolution 6 and finer
#'   each edge is a single segment. Pass a larger value when the polygons are
#'   used for spatial tests rather than display.
#' @returns A `wk_wkt` or `wk_wkb` vector of polygon geometries with
#'   `wk::wk_crs_longlat()` CRS.
#'
#' @seealso [a5_cell_to_boundary_xy()] for the same vertices as flat
#'   coordinate vectors; [a5_cell_to_lonlat()] for cell centroids.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_boundary(cell)
#' a5_cell_to_boundary(cell, format = "wkt")
a5_cell_to_boundary <- function(
  cell,
  format = c("wkb", "wkt"),
  closed = TRUE,
  segments = NULL
) {
  cell <- as_a5_cell(cell)
  format <- arg_match_default(format, c("wkb", "wkt"))
  closed <- vctrs::vec_cast(closed, logical())
  check_flag(closed)
  segments <- check_segments(segments)
  cd <- cell_data(cell)
  if (format == "wkb") {
    raw_list <- a5_cell_to_boundary_wkb_rs(cd, closed, segments)
    wk::new_wk_wkb(raw_list, crs = wk::wk_crs_longlat())
  } else {
    wkt <- a5_cell_to_boundary_rs(cd, closed, segments)
    wk::new_wk_wkt(wkt, crs = wk::wk_crs_longlat())
  }
}

#' Get cell boundary vertices as flat coordinate vectors
#'
#' Returns the boundary vertices of every cell in one pair of coordinate
#' vectors, with a vector of per-cell vertex counts. This skips building a
#' geometry for each cell, so it suits drawing many cells at once, for
#' example as a single [grid::polygonGrob()] with `id.lengths = lengths`.
#'
#' The vertices and their order are those of [a5_cell_to_boundary()].
#' Longitudes within a ring are continuous, as in the other A5 libraries: a
#' ring that crosses the antimeridian continues past 180 or -180 instead of
#' jumping, so `x` can fall outside \[-180, 180\]. Shift or split such rings
#' before drawing them on a map that wraps at the antimeridian. A ring around
#' a pole cannot be drawn as a simple polygon in longitude and latitude.
#'
#' @inheritParams a5_cell_to_boundary
#' @param closed Logical scalar; if `TRUE` each ring repeats its first vertex
#'   at the end. Defaults to `FALSE`, unlike [a5_cell_to_boundary()], since
#'   polygon drawing closes rings itself.
#' @returns A list with three elements:
#'   - `x`: double vector of longitudes, every cell's vertices in turn.
#'   - `y`: double vector of latitudes, aligned with `x`.
#'   - `lengths`: integer vector with the number of vertices of each cell,
#'     the same length as `cell`. An `NA` cell has length 0.
#'
#' @seealso [a5_cell_to_boundary()] for polygon geometries.
#' @export
#' @examples
#' cells <- a5_lonlat_to_cell(c(-3.19, -3.10), c(55.95, 55.90), resolution = 9)
#' xy <- a5_cell_to_boundary_xy(cells)
#' xy$lengths
#'
#' # one grob for all cells
#' grob <- grid::polygonGrob(
#'   xy$x, xy$y,
#'   id.lengths = xy$lengths,
#'   default.units = "native"
#' )
a5_cell_to_boundary_xy <- function(cell, closed = FALSE, segments = NULL) {
  cell <- as_a5_cell(cell)
  closed <- vctrs::vec_cast(closed, logical())
  check_flag(closed)
  segments <- check_segments(segments)
  a5_cell_to_boundary_xy_rs(cell_data(cell), closed, segments)
}

#' Validate `segments`: `NULL` or a single integer of at least 1
#' @noRd
check_segments <- function(segments, call = rlang::caller_env()) {
  if (is.null(segments)) {
    return(NULL)
  }
  segments <- vctrs::vec_cast(segments, integer(), call = call)
  check_size1(segments, call = call)
  if (is.na(segments) || segments < 1L) {
    cli::cli_abort(
      "{.arg segments} must be a positive integer or `NULL`, not {segments}.",
      call = call
    )
  }
  segments
}
