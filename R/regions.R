#' Cells whose centres lie inside a polygon
#'
#' Returns A5 cells at `resolution` whose centres fall inside the polygon.
#' Multi-feature inputs (a `MULTIPOLYGON`, an `sfc` of multiple polygons,
#' or a `POLYGON` with holes) are handled natively: per polygon part, the
#' outer ring and its holes are converted together with hole interiors
#' excluded, then the results are unioned across parts. The final cell set
#' is compacted; use [a5_uncompact()] to expand to a uniform-resolution grid.
#'
#' @param x A polygon-like geometry. One of:
#'   - Any geometry handleable by [wk::wk_handle()] (e.g. [wk::wkt()],
#'     [wk::wkb()], [wk::rct()], `sf`, `sfc`) containing one or more
#'     `POLYGON` / `MULTIPOLYGON` features.
#'   - A `SpatVector` of polygons (requires the `terra` package).
#'   - A two-column numeric matrix (`cbind(lon, lat)`) of vertices,
#'     interpreted as a single outer ring.
#'   - A `data.frame` with columns `lon` and `lat`, interpreted as a
#'     single outer ring.
#' @param resolution Integer scalar target resolution (0-30).
#'
#' @returns An [a5_cell] vector at or coarser than `resolution`.
#'
#' @details
#' Membership is determined by **centre-point containment**: a cell is
#' included iff its centroid lies inside the polygon, with hole rings
#' properly subtracted. This is distinct from [a5_grid()]'s
#' boundary-intersection semantics; for the same polygon the two
#' functions can return slightly different cell sets near the boundary.
#'
#' Coordinates must be WGS 84 longitude/latitude in degrees. Rings are
#' closed automatically; a trailing duplicate vertex is dropped if
#' present.
#'
#' Where no A5 cell centroids at the specified `resolution` fall within
#' the geometry, an empty `a5_cell` vector is returned.
#'
#' Matrix and `data.frame` inputs are treated as a single ring; for
#' multi-feature data or polygons with holes, pass an `sf`, `sfc`, wk,
#' or `SpatVector` geometry instead.
#'
#' @seealso [a5_linestring_to_cells()], [a5_uncompact()].
#' @export
#' @examples
#' poly <- wk::wkt(
#'   "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))"
#' )
#' cells <- a5_polygon_to_cells(poly, resolution = 8)
#' length(cells)
a5_polygon_to_cells <- function(x, resolution) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)

  bundle <- prepare_polygon_input(x)

  cells_from_rs(a5_polygon_to_cells_rs(
    bundle$lon,
    bundle$lat,
    bundle$offsets,
    bundle$part_id,
    bundle$is_outer,
    resolution
  ))
}

#' Cells traced by a great-circle linestring
#'
#' Returns the A5 cells at `resolution` whose pentagons are intersected by
#' the great-circle polyline connecting the supplied waypoints. Output is
#' uncompacted, in discovery order along the path, with duplicates removed
#' first-seen. Multi-feature inputs (a `MULTILINESTRING` or an `sfc` of
#' multiple linestrings) are handled natively: per-feature cell sequences
#' are concatenated in feature order with first-seen deduplication.
#'
#' @param x A linestring-like geometry. One of:
#'   - Any geometry handleable by [wk::wk_handle()] containing one or
#'     more `LINESTRING` / `MULTILINESTRING` features.
#'   - A `SpatVector` of linestrings (requires the `terra` package).
#'   - A two-column numeric matrix (`cbind(lon, lat)`) of waypoints.
#'   - A `data.frame` with columns `lon` and `lat`.
#' @param resolution Integer scalar target resolution (0--30).
#'
#' @returns An [a5_cell] vector at `resolution`.
#'
#' @details
#' Consecutive waypoints are connected by great-circle arcs (not rhumb
#' lines or planar segments), so antimeridian-crossing paths work
#' transparently when written in unwrapped lon/lat.
#'
#' Matrix and `data.frame` inputs are treated as a single linestring;
#' for multi-feature data, pass an `sf`, `sfc`, wk, or `SpatVector`
#' geometry instead.
#'
#' @seealso [a5_polygon_to_cells()], [a5_grid_disk()].
#' @export
#' @examples
#' line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
#' cells <- a5_linestring_to_cells(line, resolution = 6)
#' length(cells)
a5_linestring_to_cells <- function(x, resolution) {
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  vctrs::vec_assert(resolution, size = 1L)

  bundle <- prepare_linestring_input(x)

  cells_from_rs(a5_linestring_to_cells_rs(
    bundle$lon,
    bundle$lat,
    bundle$offsets,
    resolution
  ))
}

# -- input preparation ---------------------------------------------------------

#' Flatten polygon input to per-ring (lon, lat, offsets, part_id, is_outer)
#'
#' Returns `list(lon, lat, offsets, part_id, is_outer)`. `offsets` is
#' cumulative; ring `i` occupies `offsets[i] + 1` to `offsets[i + 1]`.
#' `part_id[i]` groups rings by polygon part. `is_outer[i]` is `1L` for
#' an outer ring and `0L` for a hole ring.
#' @noRd
prepare_polygon_input <- function(x, call = rlang::caller_env()) {
  x <- maybe_coerce_spatvector(x, call = call)
  bundle <- if (is.matrix(x)) {
    coords_from_matrix(x, call = call)
  } else if (is.data.frame(x) && !inherits(x, "sf")) {
    coords_from_data_frame(x, call = call)
  } else {
    coords_from_wk_polygons(x, call = call)
  }

  if (length(bundle$offsets) < 2L) {
    cli::cli_abort("{.arg x} contains no polygon rings.", call = call)
  }
  validate_feature_sizes(bundle, expected = "polygon", call = call)
  if (anyNA(bundle$lon) || anyNA(bundle$lat)) {
    cli::cli_abort(
      "{.arg x} must not contain {.code NA} coordinates.",
      call = call
    )
  }
  bundle
}

#' Flatten linestring input to (lon, lat, offsets)
#' @noRd
prepare_linestring_input <- function(x, call = rlang::caller_env()) {
  x <- maybe_coerce_spatvector(x, call = call)
  bundle <- if (is.matrix(x)) {
    coords_from_matrix(x, call = call)
  } else if (is.data.frame(x) && !inherits(x, "sf")) {
    coords_from_data_frame(x, call = call)
  } else {
    coords_from_wk_linestrings(x, call = call)
  }

  if (length(bundle$offsets) < 2L) {
    cli::cli_abort("{.arg x} contains no linestrings.", call = call)
  }
  validate_feature_sizes(bundle, expected = "linestring", call = call)
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
    cli::cli_abort("Matrix input must be numeric.", call = call)
  }
  lon <- as.numeric(x[, 1L])
  lat <- as.numeric(x[, 2L])
  list(
    lon = lon,
    lat = lat,
    offsets = c(0L, length(lon)),
    part_id = 1L,
    is_outer = 1L
  )
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
  list(
    lon = lon,
    lat = lat,
    offsets = c(0L, length(lon)),
    part_id = 1L,
    is_outer = 1L
  )
}

#' @noRd
coords_from_wk_polygons <- function(x, call = rlang::caller_env()) {
  meta <- safe_wk_meta(x, call = call)

  # wk_meta() geometry_type codes: 3 = POLYGON, 6 = MULTIPOLYGON.
  allowed <- c(POLYGON = 3L, MULTIPOLYGON = 6L)
  bad <- !is.na(meta$geometry_type) & !(meta$geometry_type %in% allowed)
  if (any(bad)) {
    cli::cli_abort(
      "{.arg x} must contain only {paste(names(allowed), collapse = ' or ')} geometries.",
      call = call
    )
  }
  if (any(meta$is_empty)) {
    cli::cli_abort("{.arg x} contains empty geometries.", call = call)
  }

  coords <- wk::wk_coords(x)
  if (nrow(coords) == 0L) {
    return(list(
      lon = numeric(),
      lat = numeric(),
      offsets = 0L,
      part_id = integer(),
      is_outer = integer()
    ))
  }

  # Ring grouping (feature_id, part_id, ring_id) — first-seen order.
  ring_key <- paste(
    coords$feature_id,
    coords$part_id,
    coords$ring_id,
    sep = "/"
  )
  ring_group <- match(ring_key, unique(ring_key))

  # Polygon-part grouping (feature_id, part_id) — first-seen order.
  part_key <- paste(coords$feature_id, coords$part_id, sep = "/")
  row_part_id <- match(part_key, unique(part_key))

  rle_rings <- rle(ring_group)
  offsets <- c(0L, cumsum(rle_rings$lengths))
  ring_starts <- offsets[-length(offsets)] + 1L

  ring_part_id <- row_part_id[ring_starts]
  # Within a polygon part, the first ring (smallest ring_id) is the outer
  # and any later rings are holes. wk emits rings in outer-first order, so
  # the first occurrence of each part_id marks the outer ring.
  ring_is_outer <- as.integer(!duplicated(ring_part_id))

  # Closed rings (trailing duplicate vertex) are passed through as-is;
  # `a5::polygon_to_cells` strips the closing vertex natively.
  list(
    lon = as.numeric(coords$x),
    lat = as.numeric(coords$y),
    offsets = as.integer(offsets),
    part_id = as.integer(ring_part_id),
    is_outer = as.integer(ring_is_outer)
  )
}

#' @noRd
coords_from_wk_linestrings <- function(x, call = rlang::caller_env()) {
  meta <- safe_wk_meta(x, call = call)

  # wk_meta() geometry_type codes: 2 = LINESTRING, 5 = MULTILINESTRING.
  allowed <- c(LINESTRING = 2L, MULTILINESTRING = 5L)
  bad <- !is.na(meta$geometry_type) & !(meta$geometry_type %in% allowed)
  if (any(bad)) {
    cli::cli_abort(
      "{.arg x} must contain only {paste(names(allowed), collapse = ' or ')} geometries.",
      call = call
    )
  }
  if (any(meta$is_empty)) {
    cli::cli_abort("{.arg x} contains empty geometries.", call = call)
  }

  coords <- wk::wk_coords(x)
  if (nrow(coords) == 0L) {
    return(list(lon = numeric(), lat = numeric(), offsets = 0L))
  }

  # Linestrings: one ring_id per linestring (within a feature/part).
  line_key <- paste(
    coords$feature_id,
    coords$part_id,
    coords$ring_id,
    sep = "/"
  )
  line_group <- match(line_key, unique(line_key))
  rle_lines <- rle(line_group)
  offsets <- c(0L, cumsum(rle_lines$lengths))

  list(
    lon = as.numeric(coords$x),
    lat = as.numeric(coords$y),
    offsets = as.integer(offsets)
  )
}

#' Coerce a terra `SpatVector` to a wk-handleable WKT vector
#'
#' terra does not register `wk_handle()` methods, so we route SpatVector
#' inputs through `terra::geom(x, wkt = TRUE)` and wrap the result in a
#' `wk_wkt` vector. `terra` is in `Suggests`; this path errors with a
#' clear install hint if the package is missing.
#' @noRd
maybe_coerce_spatvector <- function(x, call = rlang::caller_env()) {
  if (!inherits(x, "SpatVector")) {
    return(x)
  }
  rlang::check_installed("terra", reason = "to convert terra SpatVector input.")
  wk::wkt(terra::geom(x, wkt = TRUE))
}

#' @noRd
safe_wk_meta <- function(x, call = rlang::caller_env()) {
  tryCatch(
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
}

#' @noRd
validate_feature_sizes <- function(
  bundle,
  expected,
  call = rlang::caller_env()
) {
  sizes <- diff(bundle$offsets)
  min_size <- switch(expected, polygon = 3L, linestring = 2L)
  short <- which(sizes < min_size)
  if (length(short) > 0L) {
    cli::cli_abort(
      "Each {expected} ring must have at least {min_size} vertices; \\
       ring {short[1]} has {sizes[short[1]]}.",
      call = call
    )
  }
  invisible(bundle)
}
