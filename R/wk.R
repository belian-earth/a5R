#' wk methods for a5_cell
#'
#' Integration with the [wk][wk::wk-package] geometry framework. Allows
#' `a5_cell` vectors to be handled as geometry (via their boundary polygons)
#' and to report their CRS.
#'
#' @param handleable,x An [a5_cell] vector.
#' @param handler A [wk handler][wk::wk_handle].
#' @param ... Passed to underlying methods.
#' @returns
#' - `wk_handle()`: the result of the handler.
#' - `wk_crs()`: a [wk::wk_crs] object (WGS 84 lon/lat).
#' @name wk_methods
NULL

#' @exportS3Method wk::wk_handle
#' @rdname wk_methods
wk_handle.a5_cell <- function(handleable, handler, ...) {
  geom <- a5_cell_to_boundary(handleable, format = "wkb")
  wk::wk_handle(geom, handler, ...)
}

#' @exportS3Method wk::wk_crs
#' @rdname wk_methods
wk_crs.a5_cell <- function(x) {
  wk::wk_crs_longlat()
}
