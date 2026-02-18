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
#' Grid generation runs entirely in Rust. The algorithm expands cells 3
#' resolution levels at a time (64x expansion) and prunes by bounding-box
#' overlap at each step, keeping the working set small. At intermediate
#' resolutions a spatial buffer is applied to avoid pruning cells whose
#' children straddle the target boundary (A5 cells are not strictly
#' geometrically nested across resolutions). For non-bbox geometry inputs,
#' a final exact intersection filter (via the Rust `geo` crate) removes
#' cells that fall outside the target shape.
#'
#' No artificial cell count limit is imposed. High resolution combined with a
#' large area can produce very large results and consume significant memory.
#'
#' In addition to numeric bounding boxes, `x` accepts any geometry that
#' [wk::wk_handle()] can process, including `sf`/`sfc` objects,
#' [wk::wkt()], [wk::wkb()], and [a5_cell] vectors. Multiple geometries are
#' collected into a GEOMETRYCOLLECTION automatically. Input geometries are
#' assumed to use WGS 84 (longitude/latitude) coordinates; projected
#' geometries are not reprojected and will produce incorrect results.
#'
#' Antimeridian-crossing bounding boxes are supported: when `xmin > xmax`
#' in a numeric input (e.g. `c(170, -50, -170, -30)`), the bbox is
#' automatically split into two rectangles either side of the antimeridian.
#'
#' **Known limitation:** spatial filtering uses planar geometry on
#' longitude/latitude coordinates. This can produce incomplete results for
#' target areas very close to the poles (above ~88° latitude) or touching
#' the antimeridian (longitude ±180°), where cell boundary polygons do not
#' accurately represent their true spherical coverage. For these areas, use
#' a larger target geometry to ensure complete coverage.
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
    cells1 <- new_a5_cell(a5_grid_bbox_rs(x[[1]], x[[2]], 180, x[[4]], resolution))
    cells2 <- new_a5_cell(a5_grid_bbox_rs(-180, x[[2]], x[[3]], x[[4]], resolution))
    cells <- vctrs::vec_c(cells1, cells2)
  } else {
    if (is_bbox) {
      bb <- list(xmin = x[[1]], ymin = x[[2]], xmax = x[[3]], ymax = x[[4]])
    } else {
      bb <- unclass(wk::wk_bbox(x))
    }
    cells <- new_a5_cell(a5_grid_bbox_rs(bb$xmin, bb$ymin, bb$xmax, bb$ymax, resolution))
  }

  if (length(cells) == 0L) {
    cli::cli_warn(c(
      "!" = "No cells found at resolution {resolution}.",
      "i" = "This can happen for targets near the poles or antimeridian.",
      "i" = "Try a slightly larger target area."
    ))
    return(cells)
  }

  # Final exact filter for non-bbox inputs
  if (!is_bbox) {
    target_wkt <- as_target_wkt(x)
    filtered <- a5_grid_intersects_rs(vctrs::vec_data(cells), target_wkt)
    cells <- new_a5_cell(filtered)
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
