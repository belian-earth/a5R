#' Cells inside or overlapping a polygon
#'
#' Returns, for each polygon feature, an [a5_covering] of the A5 cells at
#' `resolution` that belong to it. By default a cell belongs when its centre
#' lies inside the polygon; set `containment = "overlapping"` to also include
#' every cell that touches the polygon boundary, giving gap-free coverage.
#'
#' The result has one covering per feature, so it can be added as a column:
#' `sf_data$cells <- a5_polygon_to_cells(sf_data, 10)`. A feature's parts (a
#' `MULTIPOLYGON`) and holes are combined into its covering, with hole
#' interiors excluded. To combine features into one covering, use
#' [a5_union()]. Coverings are compacted; use [a5_uncompact()] for the cells
#' at `resolution`.
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
#' @param containment Character scalar selecting which cells to include.
#'   `"centre"` (the default; `"center"` also works) includes a cell when its
#'   centre lies inside the polygon. `"overlapping"` additionally includes
#'   every cell that overlaps the polygon boundary, so the result fully
#'   covers the polygon.
#'   The overlapping set is a superset of the centre set.
#'
#' @returns An [a5_covering] vector with one element per feature (one for
#'   matrix and `data.frame` input). `NA` for a missing geometry; an empty
#'   covering for an empty geometry or one too small to hold a cell centre.
#'
#' @details
#' With `containment = "centre"`, membership is determined by
#' **centre-point containment**: a cell is included if its centroid lies
#' inside the polygon, with hole interiors excluded. Cells straddling the
#' boundary whose centre falls outside are dropped, so the union of the
#' cells does not fully cover the polygon.
#'
#' With `containment = "overlapping"`, every cell that contains any point
#' of the polygon boundary is kept as well, so the returned cells cover
#' the polygon without gaps. Hole boundaries count as boundary, so cells
#' straddling a hole edge are included while the hole interior is still
#' excluded.
#'
#' Coordinates must be WGS 84 longitude/latitude in degrees. Rings are
#' closed automatically; a trailing duplicate vertex is dropped if
#' present. An outer ring with fewer than 3 distinct vertices gives an empty
#' covering, and a hole with fewer than 3 is ignored, as in the other A5
#' libraries.
#'
#' Polygon edges are great-circle arcs, the shortest path on the sphere
#' between consecutive vertices, as in the other A5 libraries and in s2. An
#' edge between two points on the same parallel therefore bows toward the
#' pole: a 20 degree edge along 10 degrees north peaks at 10.15 degrees
#' north, and a 1 degree edge at that latitude bows by about 40 m. An edge
#' whose ends are antipodal has no single great circle and gives an
#' undefined result. Where
#' edges should follow parallels, as in GeoJSON (RFC 7946 defines its edges
#' as straight in longitude and latitude), add vertices along them first.
#'
#' A [wk::rct()] box is a polygon with great-circle edges like any other,
#' with two exceptions: a box covering the whole globe (`wk::rct(-180, -90,
#' 180, 90)`) gives every cell, and a box reaching from pole to pole keeps
#' its west and east edges on their meridians. Any other box spanning 180
#' degrees of longitude or more is an error, because its top and bottom
#' edges would run the short way round the globe.
#'
#' Rings must not cross themselves. A self-intersecting ring, such as a bow
#' tie, gives an undefined result that can include cells thousands of
#' kilometres outside the polygon. Because edges are great circles, a ring
#' that is valid in longitude and latitude can still cross itself on the
#' sphere; `s2::s2_is_valid()` checks rings with the same edge model.
#'
#' Where no A5 cell centroids at the specified `resolution` fall within
#' the geometry, its covering is empty.
#'
#' Matrix and `data.frame` inputs are treated as a single ring; for
#' multi-feature data or polygons with holes, pass an `sf`, `sfc`, wk,
#' or `SpatVector` geometry instead.
#'
#' @seealso [a5_line_string_to_cells()], [a5_uncompact()].
#' @export
#' @examples
#' poly <- wk::wkt(
#'   "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))"
#' )
#' covering <- a5_polygon_to_cells(poly, resolution = 8)
#' covering
#' a5_uncompact(covering)
#'
#' # Gap-free coverage: every cell touching the polygon
#' a5_polygon_to_cells(poly, resolution = 8, containment = "overlapping")
#'
#' # One covering per feature
#' polys <- wk::wkt(c(
#'   "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))",
#'   NA,
#'   "POLYGON ((-4.3 55.8, -4.2 55.8, -4.2 55.9, -4.3 55.9, -4.3 55.8))"
#' ))
#' a5_polygon_to_cells(polys, resolution = 8)
a5_polygon_to_cells <- function(x, resolution,
                                containment = c("centre", "overlapping")) {
  resolution <- check_scalar_resolution(resolution)
  if (identical(containment, "center")) containment <- "centre"
  containment <- arg_match_default(containment, c("centre", "overlapping"))

  if (inherits(x, "wk_rct")) {
    return(rct_to_cells(x, resolution, containment))
  }
  polygons_to_coverings(x, resolution, containment)
}

#' @noRd
polygons_to_coverings <- function(x, resolution, containment,
                                  call = rlang::caller_env()) {
  bundle <- prepare_polygon_input(x, call = call)

  out <- coverings_from_rs(a5_polygon_to_cells_rs(
    bundle$lon,
    bundle$lat,
    bundle$offsets,
    bundle$part_id,
    bundle$is_outer,
    bundle$part_feature,
    bundle$n_features,
    resolution,
    containment
  ))
  out[bundle$missing] <- NA
  out
}

#' Coverings of `wk_rct` boxes
#'
#' A box's edges are great circles, like any polygon's. Three kinds of box
#' need care:
#' - A box covering the whole globe has its west and east edges on the same
#'   meridian and its other edges at the poles, so its ring has no area. It
#'   gives every cell.
#' - A box reaching from pole to pole has west and east edges between
#'   antipodal points, which lie on every meridian. Adding each edge's
#'   midpoint pins it to its own meridian. A meridian is a great circle, so
#'   the box keeps its meaning.
#' - Any other box spanning 180 degrees of longitude or more has top and
#'   bottom edges that run the short way round the globe, so it is refused.
#' @noRd
rct_to_cells <- function(x, resolution, containment,
                         call = rlang::caller_env()) {
  b <- unclass(x)
  width <- b$xmax - b$xmin
  height <- b$ymax - b$ymin
  globe <- !is.na(width) & width >= 360 & height >= 180
  wide <- !is.na(width) & width >= 180 & !globe
  if (any(wide)) {
    i <- which(wide)[1]
    a5_abort("geometry",
      c(
        "Box {i} of {.arg x} spans {width[i]} degrees of longitude.",
        i = "Box edges are great circles, so a box 180 degrees wide or more \
             is ambiguous unless it covers the whole globe. Split it into \
             narrower boxes."
      ),
      call = call
    )
  }

  geom <- wk::as_wkb(x)
  polar <- which(!globe & !is.na(height) & height >= 180)
  if (length(polar) > 0L) {
    xmin <- b$xmin[polar]
    xmax <- b$xmax[polar]
    ymin <- b$ymin[polar]
    ymax <- b$ymax[polar]
    ymid <- (ymin + ymax) / 2
    ring_x <- rbind(xmin, xmax, xmax, xmax, xmin, xmin)
    ring_y <- rbind(ymin, ymin, ymid, ymax, ymax, ymid)
    geom[polar] <- wk::as_wkb(wk::wk_polygon(
      wk::xy(as.vector(ring_x), as.vector(ring_y)),
      feature_id = rep(seq_along(polar), each = 6L)
    ))
  }

  out <- polygons_to_coverings(geom[!globe], resolution, containment, call)
  if (!any(globe)) {
    return(out)
  }
  whole <- a5_compact(a5_get_res0_cells(), resolution = resolution)
  out <- c(out, rep(whole, sum(globe)))
  out[order(c(which(!globe), which(globe)))]
}

#' Cells traced by a great-circle linestring
#'
#' Returns, for each linestring feature, the A5 cells at `resolution` whose
#' pentagons the great-circle path through its waypoints crosses. Each
#' path's cells are uncompacted and in order along it, with duplicates
#' removed first-seen; a `MULTILINESTRING` feature's parts are traced in
#' order into one path.
#'
#' @param x A linestring-like geometry. One of:
#'   - Any geometry handleable by [wk::wk_handle()] containing one or
#'     more `LINESTRING` / `MULTILINESTRING` features.
#'   - A `SpatVector` of linestrings (requires the `terra` package).
#'   - A two-column numeric matrix (`cbind(lon, lat)`) of waypoints.
#'   - A `data.frame` with columns `lon` and `lat`.
#' @param resolution Integer scalar target resolution (0--30).
#' @param simplify Logical scalar. If `TRUE` (default), return one flat
#'   [a5_cell] vector with the paths of every feature concatenated in feature
#'   order; a cell crossed by several features appears once per feature. If
#'   `FALSE`, return an [a5_cell_list] with one path per feature, suitable for
#'   a list column.
#'
#' @returns An [a5_cell] vector at `resolution`, or an [a5_cell_list] when
#'   `simplify = FALSE`. A missing or empty geometry contributes no cells (an
#'   empty element in the list form).
#'
#' @details
#' Consecutive waypoints are connected by great-circle arcs (not rhumb
#' lines or planar segments), so antimeridian-crossing paths work
#' transparently when written in unwrapped lon/lat. A line string with a
#' single waypoint gives the cell containing it.
#'
#' A path is an ordered sequence, so the result is a vector of cells rather
#' than an [a5_covering]; use [as_a5_covering()] to treat the cells a path
#' crosses as a set.
#'
#' Matrix and `data.frame` inputs are treated as a single linestring;
#' for multi-feature data, pass an `sf`, `sfc`, wk, or `SpatVector`
#' geometry instead.
#'
#' @seealso [a5_polygon_to_cells()], [a5_grid_disk()].
#' @export
#' @examples
#' line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
#' cells <- a5_line_string_to_cells(line, resolution = 6)
#' cells
#'
#' # One path per feature
#' lines <- wk::wkt(c(
#'   "LINESTRING (2.35 48.86, -0.13 51.51)",
#'   "LINESTRING (2.35 48.86, 4.83 45.76)"
#' ))
#' paths <- a5_line_string_to_cells(lines, resolution = 6, simplify = FALSE)
#' lengths(paths)
a5_line_string_to_cells <- function(x, resolution, simplify = TRUE) {
  resolution <- check_scalar_resolution(resolution)
  check_flag(simplify)

  bundle <- prepare_linestring_input(x)

  one_to_many(a5_line_string_to_cells_rs(
    bundle$lon,
    bundle$lat,
    bundle$offsets,
    bundle$line_feature,
    bundle$n_features,
    resolution,
    simplify
  ), simplify)
}

#' Deprecated: use [a5_line_string_to_cells()]
#'
#' `a5_linestring_to_cells()` was renamed [a5_line_string_to_cells()] to
#' match `line_string_to_cells()` in the other A5 libraries. The old name
#' still works but warns.
#'
#' @inheritParams a5_line_string_to_cells
#' @returns As [a5_line_string_to_cells()].
#' @keywords internal
#' @export
a5_linestring_to_cells <- function(x, resolution, simplify = TRUE) {
  cli::cli_warn(
    "{.fn a5_linestring_to_cells} was renamed {.fn a5_line_string_to_cells} in a5R 1.0.0.",
    class = c("a5R_warning_deprecated", "a5R_warning")
  )
  a5_line_string_to_cells(x, resolution, simplify)
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
  check_lonlat_crs(x, call = call)
  x <- maybe_coerce_spatvector(x, call = call)
  bundle <- if (is.matrix(x) || (is.data.frame(x) && !inherits(x, "sf"))) {
    ring <- if (is.matrix(x)) {
      coords_from_matrix(x, call = call)
    } else {
      coords_from_data_frame(x, call = call)
    }
    if (length(ring$lon) == 0L) {
      a5_abort("geometry", "{.arg x} contains no polygon rings.", call = call)
    }
    c(ring, list(part_feature = 1L, n_features = 1L, missing = FALSE))
  } else {
    coords_from_wk_polygons(x, call = call)
  }

  if (anyNA(bundle$lon) || anyNA(bundle$lat)) {
    a5_abort("geometry",
      "{.arg x} must not contain {.code NA} coordinates.",
      call = call
    )
  }
  check_lonlat_range(bundle, call = call)
  bundle
}

#' Flatten linestring input to (lon, lat, offsets)
#' @noRd
prepare_linestring_input <- function(x, call = rlang::caller_env()) {
  check_lonlat_crs(x, call = call)
  x <- maybe_coerce_spatvector(x, call = call)
  bundle <- if (is.matrix(x) || (is.data.frame(x) && !inherits(x, "sf"))) {
    line <- if (is.matrix(x)) {
      coords_from_matrix(x, call = call)
    } else {
      coords_from_data_frame(x, call = call)
    }
    if (length(line$lon) == 0L) {
      a5_abort("geometry", "{.arg x} contains no linestrings.", call = call)
    }
    c(line, list(line_feature = 1L, n_features = 1L))
  } else {
    coords_from_wk_linestrings(x, call = call)
  }

  if (anyNA(bundle$lon) || anyNA(bundle$lat)) {
    a5_abort("geometry",
      "{.arg x} must not contain {.code NA} coordinates.",
      call = call
    )
  }
  check_lonlat_range(bundle, call = call)
  bundle
}

#' @noRd
coords_from_matrix <- function(x, call = rlang::caller_env()) {
  if (ncol(x) != 2L) {
    a5_abort("geometry",
      "Matrix input must have exactly 2 columns ({.code lon}, {.code lat}); \\
       got {ncol(x)}.",
      call = call
    )
  }
  if (!is.numeric(x)) {
    a5_abort("geometry", "Matrix input must be numeric.", call = call)
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
    a5_abort("geometry",
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
    a5_abort("geometry",
      "{.arg x} must contain only {paste(names(allowed), collapse = ' or ')} geometries.",
      call = call
    )
  }
  # Missing geometries get an NA covering, empty ones an empty covering;
  # neither has coordinates.
  n_features <- nrow(meta)
  missing <- is.na(meta$geometry_type)

  coords <- wk::wk_coords(x)
  if (nrow(coords) == 0L) {
    return(list(
      lon = numeric(),
      lat = numeric(),
      offsets = 0L,
      part_id = integer(),
      is_outer = integer(),
      part_feature = integer(),
      n_features = n_features,
      missing = missing
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
  part_feature <- coords$feature_id[match(seq_len(max(row_part_id)), row_part_id)]
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
    is_outer = as.integer(ring_is_outer),
    part_feature = as.integer(part_feature),
    n_features = n_features,
    missing = missing
  )
}

#' @noRd
coords_from_wk_linestrings <- function(x, call = rlang::caller_env()) {
  meta <- safe_wk_meta(x, call = call)

  # wk_meta() geometry_type codes: 2 = LINESTRING, 5 = MULTILINESTRING.
  allowed <- c(LINESTRING = 2L, MULTILINESTRING = 5L)
  bad <- !is.na(meta$geometry_type) & !(meta$geometry_type %in% allowed)
  if (any(bad)) {
    a5_abort("geometry",
      "{.arg x} must contain only {paste(names(allowed), collapse = ' or ')} geometries.",
      call = call
    )
  }
  # Missing and empty geometries have no coordinates, so no cells.
  n_features <- nrow(meta)

  coords <- wk::wk_coords(x)
  if (nrow(coords) == 0L) {
    return(list(lon = numeric(), lat = numeric(), offsets = 0L,
                line_feature = integer(), n_features = n_features))
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
    offsets = as.integer(offsets),
    line_feature = as.integer(coords$feature_id[offsets[-length(offsets)] + 1L]),
    n_features = n_features
  )
}

#' Coerce a terra `SpatVector` to a wk-handleable WKT vector
#'
#' terra does not register `wk_handle()` methods, so we route SpatVector
#' inputs through `terra::geom(x, wkt = TRUE)` and wrap the result in a
#' `wk_wkt` vector. `terra` is in `Suggests`; this path errors with a
#' clear install hint if the package is missing.
#' Error when `x` declares a CRS that is not longitude/latitude
#'
#' Only sf and terra CRS objects can be tested reliably; other inputs rely on
#' the coordinate range check in `check_lonlat_range()`.
#' @noRd
check_lonlat_crs <- function(x, call = rlang::caller_env()) {
  lonlat <- if (inherits(x, "SpatVector")) {
    rlang::check_installed("terra", reason = "to convert terra SpatVector input.")
    terra::is.lonlat(x, perhaps = TRUE, warn = FALSE)
  } else if (inherits(x, c("sf", "sfc"))) {
    crs <- sf::st_crs(x)
    is.na(crs) || isTRUE(sf::st_is_longlat(crs))
  } else {
    TRUE
  }
  if (!isTRUE(lonlat)) {
    a5_abort("geometry",
      c(
        "{.arg x} must have longitude/latitude coordinates.",
        i = "Transform it to WGS 84 first, for example with \\
             {.code sf::st_transform(x, 4326)}."
      ),
      call = call
    )
  }
  invisible(x)
}

#' Error on coordinates that cannot be degrees of longitude and latitude
#' @noRd
check_lonlat_range <- function(bundle, call = rlang::caller_env()) {
  if (any(abs(bundle$lat) > 90) || any(abs(bundle$lon) > 360)) {
    a5_abort("geometry",
      c(
        "{.arg x} has coordinates outside the longitude/latitude range.",
        i = "Coordinates must be WGS 84 longitude and latitude in degrees."
      ),
      call = call
    )
  }
  invisible(bundle)
}

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
      a5_abort("geometry",
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

#' Bounding box of polygons with great-circle edges
#'
#' Returns, for each polygon feature, the longitude/latitude box that
#' contains its edges as A5 draws them: great circles between consecutive
#' vertices (see [a5_polygon_to_cells()]). Such an edge bows toward the pole,
#' so the box can extend beyond the latitudes of the vertices, which a plain
#' vertex bounding box would miss. A ring that winds around a pole extends
#' the box to that pole across all longitudes.
#'
#' Longitudes are continuous: a box crossing the antimeridian has `xmin`
#' between -180 and 180 and `xmax` above 180.
#'
#' @inheritParams a5_polygon_to_cells
#' @returns A [wk::rct()] vector with one box per feature (one for matrix and
#'   `data.frame` input), in WGS 84 longitude and latitude. `NA` for a
#'   missing or empty geometry.
#'
#' @seealso [a5_polygon_to_cells()]
#' @export
#' @examples
#' # an edge along 60 degrees north bows toward the pole
#' poly <- wk::wkt("POLYGON ((-30 50, 30 50, 30 60, -30 60, -30 50))")
#' a5_bbox(poly)
#' wk::wk_bbox(poly)
a5_bbox <- function(x) {
  if (inherits(x, "wk_rct")) {
    x <- wk::as_wkb(x)
  }
  bundle <- prepare_polygon_input(x)
  out <- a5_bbox_rs(
    bundle$lon,
    bundle$lat,
    bundle$offsets,
    bundle$part_id,
    bundle$is_outer,
    bundle$part_feature,
    bundle$n_features
  )
  wk::rct(out$xmin, out$ymin, out$xmax, out$ymax, crs = wk::wk_crs_longlat())
}
