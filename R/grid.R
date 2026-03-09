#' Generate a grid of A5 cells covering an area
#'
#' Returns all cells at the target resolution that intersect the given
#' geometry. Uses hierarchical flood-fill: starting from the 12 resolution-0
#' root cells, the algorithm repeatedly expands and prunes by spatial
#' intersection until the target resolution is reached.
#'
#' @param x An area specification. One of:
#'   - A numeric vector of length 4 (`c(xmin, ymin, xmax, ymax)`) interpreted
#'     as a WGS 84 bounding box.
#'   - Any geometry handleable by [wk::wk_handle()] (e.g. [wk::wkt()],
#'     [wk::wkb()], `sfc`, `sf`, [a5_cell]).
#' @param resolution Integer scalar target resolution (0--30).
#'
#' @returns An [a5_cell] vector of cells at `resolution` that intersect `x`.
#'
#' @details
#' Grid generation runs entirely in Rust via hierarchical flood-fill with
#' bounding-box pruning. For non-bbox geometry inputs, an exact intersection
#' filter removes cells that fall outside the target shape. No cell count
#' limit is imposed — high resolutions over large areas can consume
#' significant memory.
#'
#' Input geometries must use WGS 84 coordinates; projected geometries are
#' not reprojected and will produce incorrect results. Multiple geometries
#' are collected into a GEOMETRYCOLLECTION automatically.
#' Antimeridian-crossing bounding boxes are supported: when `xmin > xmax`
#' (e.g. `c(170, -50, -170, -30)`), the bbox is split at the antimeridian.
#'
#' **Limitation:** spatial filtering uses planar geometry on lon/lat
#' coordinates, which can produce incomplete results very close to the poles
#' (above ~88° latitude) or the antimeridian. Use a larger target geometry
#' to ensure complete coverage in these areas.
#'
#' @seealso [a5_cell_to_boundary()] to convert result cells to geometries.
#' @export
#' @examples
#' # Grid from a bounding box
#' cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 5)
#' cells
#'
#' # Grid from a WKT polygon
#' poly <- wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))")
#' cells <- a5_grid(poly, resolution = 5)
a5_grid <- function(x, resolution) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)

  is_bbox <- is.numeric(x)

  if (is_bbox) {
    validate_bbox(x)
  }

  # Get bbox for Rust grid generation
  if (is_bbox && x[[1]] > x[[3]]) {
    # Antimeridian-crossing: two halves
    cells1 <- cells_from_rs(a5_grid_bbox_rs(x[[1]], x[[2]], 180, x[[4]], resolution))
    cells2 <- cells_from_rs(a5_grid_bbox_rs(-180, x[[2]], x[[3]], x[[4]], resolution))
    cells <- vctrs::vec_c(cells1, cells2)
  } else {
    if (is_bbox) {
      bb <- list(xmin = x[[1]], ymin = x[[2]], xmax = x[[3]], ymax = x[[4]])
    } else {
      bb <- unclass(wk::wk_bbox(x))
    }
    cells <- cells_from_rs(
      a5_grid_bbox_rs(bb$xmin, bb$ymin, bb$xmax, bb$ymax, resolution)
    )
  }

  # Final exact filter for non-bbox inputs
  if (!is_bbox) {
    target_wkt <- as_target_wkt(x)
    filtered <- a5_grid_intersects_rs(
      vctrs::field(cells, "hi"), vctrs::field(cells, "lo"), target_wkt
    )
    cells <- cells_from_rs(filtered)
  }

  cells
}

# -- internal helpers ----------------------------------------------------------

#' Validate a numeric bounding box
#' @noRd
validate_bbox <- function(x, call = rlang::caller_env()) {
  if (length(x) != 4L) {
    cli::cli_abort(
      "Numeric {.arg x} must have length 4 ({.code c(xmin, ymin, xmax, ymax)}), not {length(x)}.",
      call = call
    )
  }
  if (anyNA(x)) {
    cli::cli_abort(
      "{.arg x} must not contain {.code NA} values.",
      call = call
    )
  }
  if (x[[2]] >= x[[4]]) {
    cli::cli_abort(
      "{.code ymin} ({x[[2]]}) must be less than {.code ymax} ({x[[4]]}).",
      call = call
    )
  }
  if (x[[1]] == x[[3]]) {
    cli::cli_abort(
      "{.code xmin} and {.code xmax} must not be equal ({x[[1]]}).",
      call = call
    )
  }
  invisible(x)
}

#' Convert geometry input to a single WKT string for Rust
#' @noRd
as_target_wkt <- function(x) {
  wkt_vec <- as.character(wk::as_wkt(x))
  if (length(wkt_vec) == 1L) {
    wkt_vec
  } else {
    paste0("GEOMETRYCOLLECTION (", paste(wkt_vec, collapse = ", "), ")")
  }
}
