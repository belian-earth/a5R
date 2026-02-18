#' Convert coordinates to A5 cell indices
#'
#' Maps longitude/latitude coordinates to A5 cell indices at the specified
#' resolution.
#'
#' @param lon Numeric vector of longitudes in degrees.
#' @param lat Numeric vector of latitudes in degrees.
#' @param resolution Integer scalar or vector of resolutions (0--30).
#' @returns An [a5_cell] vector of cell indices.
#'
#' @seealso [a5_cell_to_lonlat()] for the inverse operation.
#' @export
#' @examples
#' a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_lonlat_to_cell <- function(lon, lat, resolution) {
  args <- vctrs::vec_recycle_common(
    lon = vctrs::vec_cast(lon, double()),
    lat = vctrs::vec_cast(lat, double()),
    resolution = vctrs::vec_cast(resolution, integer())
  )
  check_resolution(args$resolution)
  out <- a5_lonlat_to_cell_rs(args$lon, args$lat, args$resolution)
  new_a5_cell(out)
}

#' Convert A5 cell indices to coordinates
#'
#' Returns the centre-point longitude and latitude of each cell.
#'
#' @param cell An [a5_cell] vector (or character coercible to one).
#' @param normalise Logical scalar. If `TRUE` (default), longitudes are
#'   wrapped to the \eqn{[-180, 180]} range and the result is returned as a
#'   [wk::xy()] vector. If `FALSE`, the raw unwrapped coordinates from the
#'   Rust API are returned as a two-column data frame (`lon`, `lat`).
#' @returns If `normalise = TRUE`, a [wk::xy()] vector of (longitude,
#'   latitude) points. If `normalise = FALSE`, a data frame with columns
#'   `lon` and `lat` containing the unwrapped coordinates.
#'
#' @details
#' The underlying Rust API returns longitudes in a continuous unwrapped range
#' that can exceed \eqn{[-180, 180]} for cells near the antimeridian
#' (e.g. \eqn{-245} instead of \eqn{115}). By default these are normalised
#' to standard bounds. Set `normalise = FALSE` to retrieve the raw values,
#' which can be useful for avoiding discontinuities in calculations that span
#' the antimeridian.
#'
#' @seealso [a5_lonlat_to_cell()] for the inverse operation,
#'   [a5_cell_to_boundary()] for full cell polygons.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_lonlat(cell)
#'
#' # Raw unwrapped coordinates
#' cell2 <- a5_lonlat_to_cell(114.8, 4.1, resolution = 5)
#' a5_cell_to_lonlat(cell2, normalise = FALSE)
a5_cell_to_lonlat <- function(cell, normalise = TRUE) {
  cell <- as_a5_cell(cell)
  ll <- a5_cell_to_lonlat_rs(vctrs::vec_data(cell), normalise)
  if (normalise) {
    wk::xy(ll$lon, ll$lat, crs = wk::wk_crs_longlat())
  } else {
    data.frame(lon = ll$lon, lat = ll$lat)
  }
}
