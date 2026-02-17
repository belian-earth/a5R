#' wk methods for a5_cell
#'
#' Integration with the [wk][wk::wk-package] geometry framework. Allows
#' `a5_cell` vectors to be handled as geometry (via their boundary polygons)
#' and to report their CRS.
#'
#' @param handleable,x An [a5_cell] vector.
#' @param handler A [wk handler][wk::wk_handle].
#' @param ... Passed to underlying methods.
#' @name wk_methods
NULL

#' @export
#' @rdname wk_methods
wk_handle.a5_cell <- function(handleable, handler, ...) {
  wkt <- a5_cell_to_boundary(handleable)
  wk::wk_handle(wkt, handler, ...)
}

#' @export
#' @rdname wk_methods
wk_crs.a5_cell <- function(x) {
  wk::wk_crs_longlat()
}
