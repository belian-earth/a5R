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
#' The algorithm expands cells 3 resolution levels at a time (64x expansion)
#' and filters by intersection at each step, keeping the working set small.
#' At intermediate resolutions a spatial buffer is applied to avoid pruning
#' cells whose children straddle the target boundary (A5 cells are not
#' strictly geometrically nested across resolutions). The final step uses
#' exact [geos::geos_intersects()] filtering.
#'
#' No artificial cell count limit is imposed. High resolution combined with a
#' large area can produce very large results and consume significant memory.
#'
#' In addition to numeric bounding boxes, `x` accepts any geometry that
#' [geos::as_geos_geometry()] can handle, including `sf`/`sfc` objects,
#' [wk::wkt()], [wk::wkb()], and [a5_cell] vectors. Multiple geometries are
#' unioned automatically. Input geometries are assumed to use WGS 84
#' (longitude/latitude) coordinates; projected geometries are not reprojected
#' and will produce incorrect results.
#'
#' Antimeridian-crossing bounding boxes are supported: when `xmin > xmax`
#' in a numeric input (e.g. `c(170, -50, -170, -30)`), the bbox is
#' automatically split into two rectangles either side of the antimeridian.
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

  target <- as_geos_area(x)

  cells <- a5_get_res0_cells()
  current_res <- 0L
  step <- 3L
  filter_start <- 3L

  while (current_res < resolution) {
    next_res <- min(current_res + step, resolution)
    cells <- a5_uncompact(cells, next_res)
    current_res <- next_res
    if (current_res >= filter_start) {
      if (current_res < resolution) {
        # Intermediate: buffer target to avoid pruning cells whose children
        # straddle the boundary (A5 hierarchy is not strictly nested spatially)
        buf_dist <- cell_buffer_distance(current_res)
        buffered <- geos::geos_buffer(target, buf_dist)
        cells <- filter_cells_by_intersection(cells, buffered)
      } else {
        # Final resolution: exact intersection
        cells <- filter_cells_by_intersection(cells, target)
      }
      if (length(cells) == 0L) return(cells)
    }
  }

  cells
}

# -- internal helpers ----------------------------------------------------------

#' Approximate cell diameter in degrees with safety margin
#'
#' Used to buffer the target geometry at intermediate resolutions so that
#' cells near the boundary are not incorrectly pruned.
#' @noRd
cell_buffer_distance <- function(resolution) {
  area_m2 <- as.numeric(a5_cell_area(resolution))
  diameter_m <- sqrt(area_m2)
  # Convert to degrees (111 km per degree at equator — conservative)
  # 50% of diameter covers observed ~10% hierarchy gaps with margin
  diameter_m / 111000 * 0.5
}

#' Normalize user input to a single geos_geometry
#' @noRd
as_geos_area <- function(x, call = rlang::caller_env()) {
  if (is.numeric(x)) {
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
    if (x[[1]] > x[[3]]) {
      # Antimeridian-crossing bbox: split into two rectangles and union
      x <- c(
        wk::rct(x[[1]], x[[2]], 180, x[[4]], crs = wk::wk_crs_longlat()),
        wk::rct(-180, x[[2]], x[[3]], x[[4]], crs = wk::wk_crs_longlat())
      )
    } else {
      x <- wk::rct(x[[1]], x[[2]], x[[3]], x[[4]], crs = wk::wk_crs_longlat())
    }
  }

  geom <- geos::as_geos_geometry(x)

  if (length(geom) > 1L) {
    geom <- geos::geos_unary_union(geos::geos_make_collection(geom))
  }

  # Ensure CRS matches cell boundaries (OGC:CRS84)
  if (is.null(wk::wk_crs(geom))) {
    geom <- wk::wk_set_crs(geom, wk::wk_crs_longlat())
  }

  geom
}

#' Filter cells to those intersecting a target geometry
#' @noRd
filter_cells_by_intersection <- function(cells, target) {
  boundaries <- a5_cell_to_boundary(cells)
  cell_geoms <- geos::as_geos_geometry(boundaries)
  hits <- geos::geos_intersects(cell_geoms, target)
  cells[hits]
}
