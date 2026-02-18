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
#' @param segments Integer scalar or `NULL`. Number of interpolation segments
#'   per edge for geodesic accuracy. `NULL` uses the default (straight edges).
#' @returns A `wk_wkt` or `wk_wkb` vector of polygon geometries with
#'   `wk::wk_crs_longlat()` CRS.
#'
#' @seealso [a5_cell_to_lonlat()] for cell centroids.
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
  format <- rlang::arg_match(format)
  closed <- vctrs::vec_cast(closed, logical())
  vctrs::vec_assert(closed, size = 1L)
  if (!is.null(segments)) {
    segments <- vctrs::vec_cast(segments, integer())
    vctrs::vec_assert(segments, size = 1L)
  }
  if (format == "wkb") {
    raw_list <- a5_cell_to_boundary_wkb_rs(vctrs::vec_data(cell), closed, segments)
    wk::new_wk_wkb(raw_list, crs = wk::wk_crs_longlat())
  } else {
    wkt <- a5_cell_to_boundary_rs(vctrs::vec_data(cell), closed, segments)
    wk::new_wk_wkt(wkt, crs = wk::wk_crs_longlat())
  }
}
