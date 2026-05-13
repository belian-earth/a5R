# -- helpers -------------------------------------------------------------------

square_wkt <- function(xmin, ymin, xmax, ymax) {
  sprintf(
    "POLYGON ((%s %s, %s %s, %s %s, %s %s, %s %s))",
    xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin
  )
}

# -- a5_polygon_to_cells: return type ------------------------------------------

test_that("a5_polygon_to_cells returns an a5_cell vector", {
  poly <- wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5))
  cells <- a5_polygon_to_cells(poly, resolution = 10)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) > 0)
  # Result is compacted, so resolutions can vary up to target.
  expect_true(all(a5_get_resolution(cells) <= 10L))
  # No duplicates.
  expect_equal(length(cells), length(unique(format(cells))))
})

test_that("a5_polygon_to_cells uses centre-point containment (centre cell is inside)", {
  poly <- wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5))
  cells <- a5_polygon_to_cells(poly, resolution = 10)
  centre <- a5_lonlat_to_cell(-3.0, 56.0, resolution = 10)
  expanded <- a5_uncompact(cells, resolution = 10)
  expect_true(format(centre) %in% format(expanded))
})

# -- input shapes --------------------------------------------------------------

test_that("a5_polygon_to_cells accepts a matrix shortcut", {
  m <- cbind(c(-3.5, -2.5, -2.5, -3.5), c(55.5, 55.5, 56.5, 56.5))
  cells_m <- a5_polygon_to_cells(m, resolution = 10)
  cells_w <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_setequal(format(cells_m), format(cells_w))
})

test_that("a5_polygon_to_cells accepts a data.frame shortcut", {
  df <- data.frame(
    lon = c(-3.5, -2.5, -2.5, -3.5),
    lat = c(55.5, 55.5, 56.5, 56.5)
  )
  cells_df <- a5_polygon_to_cells(df, resolution = 10)
  cells_w <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_setequal(format(cells_df), format(cells_w))
})

test_that("a5_polygon_to_cells accepts an sfc polygon", {
  skip_if_not_installed("sf")
  sfc <- sf::st_sfc(
    sf::st_polygon(list(matrix(
      c(-3.5, 55.5, -2.5, 55.5, -2.5, 56.5, -3.5, 56.5, -3.5, 55.5),
      ncol = 2, byrow = TRUE
    ))),
    crs = 4326
  )
  cells_sf <- a5_polygon_to_cells(sfc, resolution = 10)
  cells_w <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_setequal(format(cells_sf), format(cells_w))
})

# -- handle_multigeom: polygon -------------------------------------------------

test_that("a5_polygon_to_cells rejects POLYGON-with-holes by default", {
  poly_h <- wk::wkt(
    "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))"
  )
  expect_error(
    a5_polygon_to_cells(poly_h, resolution = 8),
    "handle_multigeom"
  )
})

test_that("a5_polygon_to_cells rejects MULTIPOLYGON by default", {
  mp <- wk::wkt(
    "MULTIPOLYGON (((0 0, 1 0, 1 1, 0 1, 0 0)), ((2 2, 3 2, 3 3, 2 3, 2 2)))"
  )
  expect_error(
    a5_polygon_to_cells(mp, resolution = 8),
    "handle_multigeom"
  )
})

test_that("a5_polygon_to_cells rejects an sfc of length > 1 by default", {
  skip_if_not_installed("sf")
  sfc <- sf::st_sfc(
    sf::st_polygon(list(matrix(c(0,0, 1,0, 1,1, 0,1, 0,0), ncol = 2, byrow = TRUE))),
    sf::st_polygon(list(matrix(c(2,2, 3,2, 3,3, 2,3, 2,2), ncol = 2, byrow = TRUE))),
    crs = 4326
  )
  expect_error(a5_polygon_to_cells(sfc, resolution = 8), "handle_multigeom")
})

test_that("a5_polygon_to_cells with handle_multigeom unions MULTIPOLYGON parts", {
  mp <- wk::wkt(
    "MULTIPOLYGON (((-3.5 55.5, -2.5 55.5, -2.5 56.5, -3.5 56.5, -3.5 55.5)),
                   ((1 1, 2 1, 2 2, 1 2, 1 1)))"
  )
  union <- a5_polygon_to_cells(mp, resolution = 8, handle_multigeom = TRUE)
  part1 <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 8
  )
  part2 <- a5_polygon_to_cells(
    wk::wkt(square_wkt(1, 1, 2, 2)),
    resolution = 8
  )
  # Each part's compacted cells should appear in the union (after uncompacting
  # both sides to the target resolution).
  u1 <- a5_uncompact(part1, resolution = 8)
  u2 <- a5_uncompact(part2, resolution = 8)
  uu <- a5_uncompact(union, resolution = 8)
  expect_true(all(format(u1) %in% format(uu)))
  expect_true(all(format(u2) %in% format(uu)))
  # And no extras.
  expect_setequal(format(uu), c(format(u1), format(u2)))
})

test_that("a5_polygon_to_cells documents additive-hole behaviour", {
  # Hole is unioned in (not subtracted); the union > the outer ring alone iff
  # the hole adds boundary cells not centred inside the outer.
  outer <- wk::wkt(square_wkt(0, 0, 4, 4))
  with_hole <- wk::wkt(
    "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))"
  )
  outer_cells <- a5_polygon_to_cells(outer, resolution = 6)
  union_cells <- a5_polygon_to_cells(with_hole, resolution = 6,
                                     handle_multigeom = TRUE)
  ou <- a5_uncompact(outer_cells, resolution = 6)
  uu <- a5_uncompact(union_cells, resolution = 6)
  # Every cell from the outer ring is also in the union (holes are additive,
  # never subtractive).
  expect_true(all(format(ou) %in% format(uu)))
})

# -- a5_linestring_to_cells ----------------------------------------------------

test_that("a5_linestring_to_cells returns ordered cells along the path", {
  line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
  cells <- a5_linestring_to_cells(line, resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) >= 2)
  # Endpoints map to the right cells.
  start <- a5_lonlat_to_cell(2.35, 48.86, resolution = 5)
  end   <- a5_lonlat_to_cell(-0.13, 51.51, resolution = 5)
  expect_true(format(start) %in% format(cells))
  expect_true(format(end) %in% format(cells))
  # No duplicates.
  expect_equal(length(cells), length(unique(format(cells))))
})

test_that("a5_linestring_to_cells matrix and data.frame shortcuts match wk input", {
  pts <- rbind(c(2.35, 48.86), c(-0.13, 51.51))
  c_w <- a5_linestring_to_cells(wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)"),
                                resolution = 5)
  c_m <- a5_linestring_to_cells(pts, resolution = 5)
  c_d <- a5_linestring_to_cells(data.frame(lon = pts[, 1], lat = pts[, 2]),
                                resolution = 5)
  expect_identical(format(c_m), format(c_w))
  expect_identical(format(c_d), format(c_w))
})

test_that("a5_linestring_to_cells rejects MULTILINESTRING by default", {
  ml <- wk::wkt("MULTILINESTRING ((0 0, 1 0), (2 0, 3 0))")
  expect_error(
    a5_linestring_to_cells(ml, resolution = 5),
    "handle_multigeom"
  )
})

test_that("a5_linestring_to_cells with handle_multigeom dedupes first-seen", {
  ml <- wk::wkt(
    "MULTILINESTRING ((2.35 48.86, -0.13 51.51),
                      (-0.13 51.51, 4.83 45.76))"
  )
  cells <- a5_linestring_to_cells(ml, resolution = 5, handle_multigeom = TRUE)
  expect_s3_class(cells, "a5_cell")
  expect_equal(length(cells), length(unique(format(cells))))
  # All three endpoint cells should appear.
  paris  <- a5_lonlat_to_cell(2.35, 48.86, resolution = 5)
  london <- a5_lonlat_to_cell(-0.13, 51.51, resolution = 5)
  lyon   <- a5_lonlat_to_cell(4.83, 45.76, resolution = 5)
  expect_true(all(c(format(paris), format(london), format(lyon)) %in%
                  format(cells)))
})

test_that("a5_linestring_to_cells handles an antimeridian-crossing path", {
  # Great-circle from (170, 0) to (-170, 0) crosses the antimeridian (20° arc).
  line <- wk::wkt("LINESTRING (170 0, -170 0)")
  cells <- a5_linestring_to_cells(line, resolution = 5)
  centres <- a5_cell_to_lonlat(cells)
  lons <- wk::wk_coords(centres)$x
  # Should include cells on both sides of the antimeridian.
  expect_true(any(lons > 160))
  expect_true(any(lons < -160))
})

# -- threading invariance ------------------------------------------------------

test_that("polygon/linestring results are identical with threads > 1", {
  prev <- a5_get_threads()
  on.exit(a5_set_threads(prev), add = TRUE)

  mp <- wk::wkt(
    "MULTIPOLYGON (((-3.5 55.5, -2.5 55.5, -2.5 56.5, -3.5 56.5, -3.5 55.5)),
                   ((1 1, 2 1, 2 2, 1 2, 1 1)))"
  )
  ml <- wk::wkt(
    "MULTILINESTRING ((2.35 48.86, -0.13 51.51),
                      (-0.13 51.51, 4.83 45.76))"
  )

  a5_set_threads(1)
  p1 <- a5_polygon_to_cells(mp, resolution = 8, handle_multigeom = TRUE)
  l1 <- a5_linestring_to_cells(ml, resolution = 5, handle_multigeom = TRUE)

  a5_set_threads(2)
  p2 <- a5_polygon_to_cells(mp, resolution = 8, handle_multigeom = TRUE)
  l2 <- a5_linestring_to_cells(ml, resolution = 5, handle_multigeom = TRUE)

  # Polygon output is sorted+compacted, so equality is structural.
  expect_setequal(format(p1), format(p2))
  # Linestring output is ordered; threading must not reshuffle.
  expect_identical(format(l1), format(l2))
})

# -- input validation ---------------------------------------------------------

test_that("invalid inputs error cleanly", {
  expect_error(
    a5_polygon_to_cells(matrix(c(0, 0, 1, 1), ncol = 2), resolution = 8),
    "at least 3 vertices"
  )
  expect_error(
    a5_linestring_to_cells(matrix(c(0, 0), ncol = 2), resolution = 8),
    "at least 2 vertices"
  )
  expect_error(
    a5_polygon_to_cells(
      data.frame(lon = c(0, 1, NA, 0), lat = c(0, 0, 1, 0)),
      resolution = 8
    ),
    "NA"
  )
  expect_error(
    a5_polygon_to_cells(wk::wkt("POINT (0 0)"), resolution = 8),
    "POLYGON"
  )
  expect_error(
    a5_linestring_to_cells(wk::wkt("POINT (0 0)"), resolution = 8),
    "LINESTRING"
  )
  expect_error(
    a5_polygon_to_cells(wk::wkt(square_wkt(0, 0, 1, 1)), resolution = -1),
    "resolution"
  )
})
