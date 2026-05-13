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
  cells_from_rs(a5_lonlat_to_cell_rs(args$lon, args$lat, args$resolution))
}

#' Convert A5 cell indices to coordinates
#'
#' Returns the centre-point longitude and latitude of each cell.
#'
#' @param cell An [a5_cell] vector (or character coercible to one).
#' @param as_dataframe Logical scalar controlling the return container.
#'   When `FALSE` (default), centroids are returned as a [wk::xy()] vector
#'   with WGS 84 CRS — the geographic-typed form that plugs into wk/sf
#'   pipelines. When `TRUE`, centroids are returned as a base `data.frame`
#'   with columns `lon` and `lat`.
#' @param normalise `r lifecycle::badge("deprecated")` Use `as_dataframe`
#'   instead. `normalise = TRUE` maps to `as_dataframe = FALSE` and vice
#'   versa. Upstream a5 (>= 0.7.3) always returns longitudes normalised to
#'   \eqn{[-180, 180]}, so this flag's original purpose (unwrapped output)
#'   no longer applies.
#' @returns A [wk::xy()] vector (if `as_dataframe = FALSE`) or a
#'   `data.frame` with columns `lon` and `lat` (if `as_dataframe = TRUE`).
#'
#' @seealso [a5_lonlat_to_cell()] for the inverse operation,
#'   [a5_cell_to_boundary()] for full cell polygons.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_lonlat(cell)
#'
#' # Data frame output
#' cell2 <- a5_lonlat_to_cell(114.8, 4.1, resolution = 5)
#' a5_cell_to_lonlat(cell2, as_dataframe = TRUE)
a5_cell_to_lonlat <- function(cell,
                              as_dataframe = FALSE,
                              normalise = lifecycle::deprecated()) {
  if (lifecycle::is_present(normalise)) {
    lifecycle::deprecate_warn(
      "0.4.0",
      "a5_cell_to_lonlat(normalise = )",
      "a5_cell_to_lonlat(as_dataframe = )",
      details = paste(
        "Pass `as_dataframe = TRUE` for a data.frame return.",
        "`as_dataframe` is the inverse of the old `normalise` flag:",
        "`normalise = TRUE` corresponds to `as_dataframe = FALSE`."
      )
    )
    as_dataframe <- !isTRUE(normalise)
  }
  cell <- as_a5_cell(cell)
  ll <- a5_cell_to_lonlat_rs(cell_data(cell), TRUE)
  if (as_dataframe) {
    data.frame(lon = ll$lon, lat = ll$lat)
  } else {
    wk::xy(ll$lon, ll$lat, crs = wk::wk_crs_longlat())
  }
}
