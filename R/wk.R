# wk integration: allow a5_cell to act as a geometry vector via
# wk_handle, so it can be plotted and transformed with the wk ecosystem.

#' @export
wk_handle.a5_cell <- function(handleable, handler, ...) {
  wkt <- a5_cell_to_boundary(handleable)
  wk::wk_handle(wkt, handler, ...)
}

#' @export
wk_crs.a5_cell <- function(x) {
  wk::wk_crs_lonlat()
}
