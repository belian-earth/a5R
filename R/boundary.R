#' Get cell boundary polygons
#'
#' Returns the boundary of each cell as a [wk::wkt()] or [wk::wkb()]
#' polygon geometry. Boundaries are pentagonal polygons on the WGS 84
#' ellipsoid.
#'
#' @param cell An [a5_cell] vector.
#' @param closed Logical scalar; if `TRUE` (default) the ring is closed
#'   (first vertex repeated at end).
#' @param segments Integer scalar or `NULL`. Number of interpolation segments
#'   per edge for geodesic accuracy. `NULL` uses the default (straight edges).
#' @returns A `wk_wkt` vector of polygon geometries with
#'   `wk::wk_crs_longlat()` CRS.
#'
#' @seealso [a5_cell_to_lonlat()] for cell centroids.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_boundary(cell)
a5_cell_to_boundary <- function(cell, closed = TRUE, segments = NULL) {
  cell <- as_a5_cell(cell)
  closed <- vctrs::vec_cast(closed, logical())
  vctrs::vec_assert(closed, size = 1L)
  if (!is.null(segments)) {
    segments <- vctrs::vec_cast(segments, integer())
    vctrs::vec_assert(segments, size = 1L)
  }
  raw <- a5_cell_to_boundary_rs(vctrs::vec_data(cell), closed, segments)
  wkt <- vapply(
    raw,
    function(ring) {
      if (length(ring$lon) == 1L && is.na(ring$lon)) {
        return(NA_character_)
      }
      coords <- paste(ring$lon, ring$lat, sep = " ")
      ring_str <- paste(coords, collapse = ", ")
      paste0("POLYGON ((", ring_str, "))")
    },
    character(1L)
  )
  wk::new_wk_wkt(wkt, crs = wk::wk_crs_longlat())
}
