#' Convert between coordinates and cells
#'
#' `a5_lonlat_to_cell()` maps longitude/latitude coordinates to the cell
#' containing each point at a resolution. `a5_cell_to_lonlat()` returns the
#' centre point of each cell. Indexing a cell's centre at the cell's own
#' resolution returns the cell.
#'
#' @param lon Numeric vector of longitudes in degrees.
#' @param lat Numeric vector of latitudes in degrees.
#' @param resolution Integer scalar or vector of resolutions (0--30),
#'   recycled against `lon` and `lat`.
#' @param cell An [a5_cell] vector (or character coercible to one).
#' @param as_dataframe Logical scalar controlling the return container.
#'   When `FALSE` (default), centres are returned as a [wk::xy()] vector
#'   with WGS 84 CRS, the geographic-typed form that plugs into wk/sf
#'   pipelines. When `TRUE`, centres are returned as a base `data.frame`
#'   with columns `lon` and `lat`.
#' @returns
#' * `a5_lonlat_to_cell()`: an [a5_cell] vector.
#' * `a5_cell_to_lonlat()`: a [wk::xy()] vector, or a `data.frame` with
#'   columns `lon` and `lat` when `as_dataframe = TRUE`.
#'
#' @seealso [a5_cell_to_boundary()] for full cell polygons,
#'   [a5_polygon_to_cells()] for areas.
#' @name a5_coordinates
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_lonlat(cell)
#' a5_cell_to_lonlat(cell, as_dataframe = TRUE)
#'
#' # a cell's centre indexes back to the cell
#' ll <- a5_cell_to_lonlat(cell, as_dataframe = TRUE)
#' a5_lonlat_to_cell(ll$lon, ll$lat, resolution = 5) == cell
NULL

#' @rdname a5_coordinates
#' @export
a5_lonlat_to_cell <- function(lon, lat, resolution) {
  args <- recycle_lonlat_resolution(lon, lat, resolution)
  check_resolution(args$resolution)
  cells_from_rs(a5_lonlat_to_cell_rs(args$lon, args$lat, args$resolution))
}

#' Cast and recycle lon/lat/resolution for the Rust entry point
#'
#' The common case (bare double coordinates of equal length, a whole-number
#' resolution of length 1 or n) is handled with base R checks, which cost a
#' fraction of a microsecond. Everything else falls through to vctrs so that
#' casting errors and recycling rules are unchanged.
#' @noRd
recycle_lonlat_resolution <- function(lon, lat, resolution) {
  n <- length(lon)
  nr <- length(resolution)
  if (
    n > 0L && length(lat) == n && (nr == n || nr == 1L) &&
      is.double(lon) && is.double(lat) && is.numeric(resolution) &&
      is_bare_vector(lon) && is_bare_vector(lat) && is_bare_vector(resolution)
  ) {
    if (is.integer(resolution)) {
      res <- resolution
    } else if (all(is.na(resolution) | (is.finite(resolution) & resolution == trunc(resolution)))) {
      res <- as.integer(resolution)
    } else {
      res <- NULL
    }
    if (!is.null(res)) {
      if (nr == 1L && n > 1L) res <- rep_len(res, n)
      return(list(lon = lon, lat = lat, resolution = res))
    }
  }
  vctrs::vec_recycle_common(
    lon = vctrs::vec_cast(lon, double()),
    lat = vctrs::vec_cast(lat, double()),
    resolution = vctrs::vec_cast(resolution, integer())
  )
}

#' @rdname a5_coordinates
#' @export
a5_cell_to_lonlat <- function(cell, as_dataframe = FALSE) {
  cell <- as_a5_cell(cell)
  ll <- a5_cell_to_lonlat_rs(cell_data(cell), TRUE)
  # Low-level constructors: the Rust output is already validated, and
  # data.frame() / wk::xy() spend tens of microseconds re-checking it.
  if (as_dataframe) {
    vctrs::new_data_frame(list(lon = ll$lon, lat = ll$lat))
  } else {
    wk::new_wk_xy(list(x = ll$lon, y = ll$lat), crs = wk::wk_crs_longlat())
  }
}

#' Is `x` a plain atomic vector with no class or dimensions?
#'
#' Classed inputs (units, difftime, ...) and matrices must go through vctrs,
#' which converts or rejects them; names and other plain attributes are
#' carried through vctrs unchanged and are ignored by the Rust side.
#' @noRd
is_bare_vector <- function(x) {
  is.null(attr(x, "class")) && is.null(attr(x, "dim"))
}
