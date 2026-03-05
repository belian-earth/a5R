#' Distance between cell centroids
#'
#' Computes the distance between the centroids of pairs of A5 cells
#' using the specified method.
#'
#' @param from,to [a5_cell] vectors (recycled to common length).
#' @param units Character scalar specifying the distance unit (default
#'   `"m"`). Any unit convertible from metres via [units::set_units()] is
#'   accepted (e.g. `"km"`, `"mi"`).
#' @param method Distance calculation method. One of `"haversine"`
#'   (great-circle, default), `"geodesic"` (WGS84 ellipsoid via Karney
#'   2013), or `"rhumb"` (loxodrome / constant-bearing).
#' @returns A [units::units] vector of distances.
#'
#' @seealso [a5_cell_to_lonlat()] for cell centroids,
#'   [a5_cell_area()] for cell areas.
#' @export
#' @examples
#' a <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 24)
#' b <- a5_lonlat_to_cell(-3.10, 55.90, resolution = 24)
#' a5_cell_distance(a, b)
#' a5_cell_distance(a, b, units = "km")
#' a5_cell_distance(a, b, method = "geodesic")
a5_cell_distance <- function(
  from,
  to,
  units = "m",
  method = c("haversine", "geodesic", "rhumb")
) {
  from <- as_a5_cell(from)
  to <- as_a5_cell(to)
  args <- vctrs::vec_recycle_common(from = from, to = to)
  method <- rlang::arg_match(method)
  if (!units::ud_are_convertible("m", units)) {
    cli::cli_abort(
      "{.arg units} must be a distance unit convertible from m, not {.val {units}}."
    )
  }
  d <- a5_cell_distance_rs(
    vctrs::vec_data(args$from),
    vctrs::vec_data(args$to),
    method
  )
  units::set_units(d, "m", mode = "standard") |>
    units::set_units(units, mode = "standard")
}
