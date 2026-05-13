#' Cells whose centres lie inside a polygon
#'
#' Returns the A5 cells at `resolution` whose centres fall inside the given
#' polygon. The result is sorted and compacted; use [a5_uncompact()] to
#' expand to a uniform-resolution grid.
#'
#' @param x A single-ring polygon. One of:
#'   - Any geometry handleable by [wk::wk_handle()] (e.g. [wk::wkt()],
#'     [wk::wkb()], `sf`, `sfc`) containing a single `POLYGON` with one ring.
#'   - A two-column numeric matrix (`cbind(lon, lat)`) of vertices.
#'   - A `data.frame` with columns `lon` and `lat`.
#' @param resolution Integer scalar target resolution (0--30).
#' @param handle_multigeom If `FALSE` (default), inputs containing more than
#'   one ring/feature (e.g. a `POLYGON` with holes, a `MULTIPOLYGON`, or an
#'   `sfc` of multiple polygons) raise an error. If `TRUE`, every ring is
#'   converted independently and the results are merged: each ring is
#'   uncompacted to `resolution`, the union of cell IDs is taken, then
#'   recompacted once at the end. Holes are treated as **additive** (their
#'   cells are unioned in, not subtracted) — pre-subtract holes yourself if
#'   you need them excluded.
#'
#' @returns An [a5_cell] vector at or coarser than `resolution`.
#'
#' @details
#' Membership is determined by **centre-point containment**: a cell is
#' included iff its centroid lies inside the polygon. This is distinct from
#' [a5_grid()]'s boundary-intersection semantics; for the same polygon the
#' two functions can return slightly different cell sets near the boundary.
#'
#' Coordinates must be WGS 84 longitude/latitude in degrees. Polygons are
#' closed automatically; do not repeat the first vertex at the end (a
#' trailing duplicate is dropped if present).
#'
#' @seealso [a5_linestring_to_cells()], [a5_grid()], [a5_uncompact()].
#' @export
#' @examples
#' poly <- wk::wkt(
#'   "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))"
#' )
#' cells <- a5_polygon_to_cells(poly, resolution = 8)
#' length(cells)
a5_polygon_to_cells <- function(x, resolution, handle_multigeom = FALSE) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)

  bundle <- prepare_geom_input(
    x,
    expected = "polygon",
    handle_multigeom = handle_multigeom
  )

  cells_from_rs(a5_polygon_to_cells_rs(
    bundle$lon, bundle$lat, bundle$offsets, resolution
  ))
}

#' Cells traced by a great-circle linestring
#'
#' Returns the A5 cells at `resolution` whose pentagons are intersected by
#' the great-circle polyline connecting the supplied waypoints. Output is
#' uncompacted, in discovery order along the path, with duplicates removed
#' first-seen.
#'
#' @param x A single linestring. One of:
#'   - Any geometry handleable by [wk::wk_handle()] containing a single
#'     `LINESTRING`.
#'   - A two-column numeric matrix (`cbind(lon, lat)`) of waypoints.
#'   - A `data.frame` with columns `lon` and `lat`.
#' @param resolution Integer scalar target resolution (0--30).
#' @param handle_multigeom If `FALSE` (default), `MULTILINESTRING` inputs
#'   and `sfc` of multiple linestrings raise an error. If `TRUE`, each
#'   linestring is traced independently and the per-feature cell sequences
#'   are concatenated in feature order with first-seen deduplication.
#'
#' @returns An [a5_cell] vector at `resolution`.
#'
#' @details
#' Consecutive waypoints are connected by great-circle arcs (not rhumb
#' lines or planar segments), so antimeridian-crossing paths work
#' transparently when written in unwrapped lon/lat.
#'
#' @seealso [a5_polygon_to_cells()], [a5_grid_disk()].
#' @export
#' @examples
#' line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
#' cells <- a5_linestring_to_cells(line, resolution = 6)
#' length(cells)
a5_linestring_to_cells <- function(x, resolution, handle_multigeom = FALSE) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)

  bundle <- prepare_geom_input(
    x,
    expected = "linestring",
    handle_multigeom = handle_multigeom
  )

  cells_from_rs(a5_linestring_to_cells_rs(
    bundle$lon, bundle$lat, bundle$offsets, resolution
  ))
}

# -- input preparation ---------------------------------------------------------

#' Flatten an input geometry to (lon, lat, offsets) per ring/linestring
#'
#' Returns `list(lon = numeric, lat = numeric, offsets = integer)` where
#' `offsets` is cumulative (length `n_features + 1`) and feature `i`
#' occupies `offsets[i] + 1` to `offsets[i + 1]`.
#'
#' @param x Input geometry, matrix, or data.frame.
#' @param expected `"polygon"` or `"linestring"`.
#' @param handle_multigeom Logical. If FALSE, more than one ring/linestring
#'   raises an error.
#' @noRd
prepare_geom_input <- function(x, expected, handle_multigeom,
                               call = rlang::caller_env()) {
  if (!is.logical(handle_multigeom) || length(handle_multigeom) != 1L ||
        is.na(handle_multigeom)) {
    cli::cli_abort(
      "{.arg handle_multigeom} must be {.code TRUE} or {.code FALSE}.",
      call = call
    )
  }

  bundle <- if (is.matrix(x)) {
    coords_from_matrix(x, call = call)
  } else if (is.data.frame(x) && !inherits(x, "sf")) {
    coords_from_data_frame(x, call = call)
  } else {
    coords_from_wk(x, expected = expected, call = call)
  }

  n_features <- length(bundle$offsets) - 1L
  if (n_features < 1L) {
    cli::cli_abort(
      "{.arg x} contains no rings or linestrings.",
      call = call
    )
  }
  if (n_features > 1L && !handle_multigeom) {
    cli::cli_abort(
      c(
        "{.arg x} contains {n_features} {expected}{?s/s} but \\
         {.arg handle_multigeom} is {.code FALSE}.",
        i = "Set {.code handle_multigeom = TRUE} to handle multi-ring \\
             polygons, multipolygons, multilinestrings, or {.cls sfc}s \\
             of multiple features."
      ),
      call = call
    )
  }

  validate_feature_sizes(bundle, expected = expected, call = call)
  if (anyNA(bundle$lon) || anyNA(bundle$lat)) {
    cli::cli_abort(
      "{.arg x} must not contain {.code NA} coordinates.",
      call = call
    )
  }

  bundle
}

#' @noRd
coords_from_matrix <- function(x, call = rlang::caller_env()) {
  if (ncol(x) != 2L) {
    cli::cli_abort(
      "Matrix input must have exactly 2 columns ({.code lon}, {.code lat}); \\
       got {ncol(x)}.",
      call = call
    )
  }
  if (!is.numeric(x)) {
    cli::cli_abort(
      "Matrix input must be numeric.",
      call = call
    )
  }
  lon <- as.numeric(x[, 1L])
  lat <- as.numeric(x[, 2L])
  list(lon = lon, lat = lat, offsets = c(0L, length(lon)))
}

#' @noRd
coords_from_data_frame <- function(x, call = rlang::caller_env()) {
  if (!all(c("lon", "lat") %in% names(x))) {
    cli::cli_abort(
      "Data frame input must have columns {.code lon} and {.code lat}.",
      call = call
    )
  }
  lon <- as.numeric(x$lon)
  lat <- as.numeric(x$lat)
  list(lon = lon, lat = lat, offsets = c(0L, length(lon)))
}

#' @noRd
coords_from_wk <- function(x, expected, call = rlang::caller_env()) {
  meta <- tryCatch(
    wk::wk_meta(x),
    error = function(e) {
      cli::cli_abort(
        c(
          "Could not interpret {.arg x} as a geometry.",
          i = "Pass a matrix, data frame with {.code lon}/{.code lat} \\
               columns, or a {.fn wk::wk_handle}-able object."
        ),
        parent = e,
        call = call
      )
    }
  )

  # wk geometry-type codes from wk::wk_meta(): 1 point, 2 linestring,
  # 3 polygon, 4 multipoint, 5 multilinestring, 6 multipolygon, 7 collection.
  allowed <- switch(
    expected,
    polygon    = c(POLYGON = 3L, MULTIPOLYGON = 6L),
    linestring = c(LINESTRING = 2L, MULTILINESTRING = 5L)
  )
  type_label <- paste(names(allowed), collapse = " or ")
  bad <- !is.na(meta$geometry_type) & !(meta$geometry_type %in% allowed)
  if (any(bad)) {
    cli::cli_abort(
      "{.arg x} must contain only {type_label} geometries.",
      call = call
    )
  }
  if (any(meta$is_empty)) {
    cli::cli_abort(
      "{.arg x} contains empty geometries.",
      call = call
    )
  }

  coords <- wk::wk_coords(x)
  if (nrow(coords) == 0L) {
    return(list(lon = numeric(), lat = numeric(), offsets = 0L))
  }

  # Group by (feature_id, part_id, ring_id) preserving first-seen order.
  group_key <- paste(coords$feature_id, coords$part_id, coords$ring_id,
                     sep = "/")
  group_id <- match(group_key, unique(group_key))

  # Cumulative offsets via run-length.
  rle_groups <- rle(group_id)
  offsets <- c(0L, cumsum(rle_groups$lengths))

  lon <- coords$x
  lat <- coords$y

  if (expected == "polygon") {
    # Drop trailing duplicate vertex per ring (WKT/WKB closed rings).
    keep <- rep(TRUE, length(lon))
    for (i in seq_len(length(offsets) - 1L)) {
      a <- offsets[i] + 1L
      b <- offsets[i + 1L]
      if (b - a >= 1L &&
            isTRUE(lon[a] == lon[b]) &&
            isTRUE(lat[a] == lat[b])) {
        keep[b] <- FALSE
      }
    }
    if (!all(keep)) {
      # Re-derive offsets after dropping the closing vertices.
      lon <- lon[keep]
      lat <- lat[keep]
      kept_groups <- group_id[keep]
      rle_groups <- rle(kept_groups)
      offsets <- c(0L, cumsum(rle_groups$lengths))
    }
  }

  list(lon = as.numeric(lon), lat = as.numeric(lat),
       offsets = as.integer(offsets))
}

#' @noRd
validate_feature_sizes <- function(bundle, expected,
                                   call = rlang::caller_env()) {
  sizes <- diff(bundle$offsets)
  min_size <- switch(expected, polygon = 3L, linestring = 2L)
  short <- which(sizes < min_size)
  if (length(short) > 0L) {
    cli::cli_abort(
      "Each {expected} must have at least {min_size} vertices; \\
       feature {short[1]} has {sizes[short[1]]}.",
      call = call
    )
  }
  invisible(bundle)
}
