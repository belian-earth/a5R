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
  expect_true(all(a5_get_resolution(cells) <= 10L))
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

test_that("a5_polygon_to_cells accepts wk::rct", {
  rect_cells <- a5_polygon_to_cells(wk::rct(-3.5, 55.5, -2.5, 56.5),
                                    resolution = 10)
  wkt_cells <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_setequal(format(rect_cells), format(wkt_cells))
})

test_that("a5_polygon_to_cells accepts a terra SpatVector", {
  skip_if_not_installed("terra")
  sv <- terra::vect(square_wkt(-3.5, 55.5, -2.5, 56.5))
  cells_terra <- a5_polygon_to_cells(sv, resolution = 10)
  cells_w <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_setequal(format(cells_terra), format(cells_w))
})

test_that("a5_polygon_to_cells handles a multi-polygon SpatVector", {
  skip_if_not_installed("terra")
  sv <- terra::vect(c(
    square_wkt(-3.5, 55.5, -2.5, 56.5),
    square_wkt(1, 1, 2, 2)
  ))
  cells_terra <- a5_polygon_to_cells(sv, resolution = 8)
  cells_w <- a5_polygon_to_cells(
    wk::wkt(c(
      square_wkt(-3.5, 55.5, -2.5, 56.5),
      square_wkt(1, 1, 2, 2)
    )),
    resolution = 8
  )
  expect_setequal(format(cells_terra), format(cells_w))
})

test_that("a5_linestring_to_cells accepts a terra SpatVector", {
  skip_if_not_installed("terra")
  sv <- terra::vect("LINESTRING (2.35 48.86, -0.13 51.51)")
  cells_terra <- a5_linestring_to_cells(sv, resolution = 5)
  cells_w <- a5_linestring_to_cells(
    wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)"),
    resolution = 5
  )
  expect_identical(format(cells_terra), format(cells_w))
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

# -- multi-feature: handled natively ------------------------------------------

test_that("MULTIPOLYGON returns the union of cells across parts", {
  mp <- wk::wkt(
    "MULTIPOLYGON (((-3.5 55.5, -2.5 55.5, -2.5 56.5, -3.5 56.5, -3.5 55.5)),
                   ((1 1, 2 1, 2 2, 1 2, 1 1)))"
  )
  union_cells <- a5_polygon_to_cells(mp, resolution = 8)
  part1 <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 8
  )
  part2 <- a5_polygon_to_cells(
    wk::wkt(square_wkt(1, 1, 2, 2)),
    resolution = 8
  )
  u1 <- a5_uncompact(part1, resolution = 8)
  u2 <- a5_uncompact(part2, resolution = 8)
  uu <- a5_uncompact(union_cells, resolution = 8)
  expect_setequal(format(uu), c(format(u1), format(u2)))
})

test_that("sfc of multiple polygons returns the union", {
  skip_if_not_installed("sf")
  sfc <- sf::st_sfc(
    sf::st_polygon(list(matrix(
      c(-3.5, 55.5, -2.5, 55.5, -2.5, 56.5, -3.5, 56.5, -3.5, 55.5),
      ncol = 2, byrow = TRUE
    ))),
    sf::st_polygon(list(matrix(
      c(1, 1, 2, 1, 2, 2, 1, 2, 1, 1),
      ncol = 2, byrow = TRUE
    ))),
    crs = 4326
  )
  cells <- a5_polygon_to_cells(sfc, resolution = 8)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) > 0)
})

# -- holes are properly subtracted --------------------------------------------

test_that("polygon-with-hole subtracts hole cells from the outer", {
  outer <- wk::wkt(square_wkt(0, 0, 4, 4))
  with_hole <- wk::wkt(
    "POLYGON ((0 0, 4 0, 4 4, 0 4, 0 0), (1 1, 2 1, 2 2, 1 2, 1 1))"
  )
  hole <- wk::wkt(square_wkt(1, 1, 2, 2))

  outer_u <- a5_uncompact(a5_polygon_to_cells(outer, resolution = 6),
                          resolution = 6)
  hole_u  <- a5_uncompact(a5_polygon_to_cells(hole, resolution = 6),
                          resolution = 6)
  result_u <- a5_uncompact(a5_polygon_to_cells(with_hole, resolution = 6),
                           resolution = 6)

  # Expected: outer cells minus hole cells.
  expected <- setdiff(format(outer_u), format(hole_u))
  expect_setequal(format(result_u), expected)
})

test_that("hole that lies wholly inside the outer leaves a real gap", {
  # The hole is centred inside the outer; some cells fall fully inside it.
  with_hole <- wk::wkt(
    "POLYGON ((0 0, 8 0, 8 8, 0 8, 0 0), (3 3, 5 3, 5 5, 3 5, 3 3))"
  )
  hole_alone <- wk::wkt(square_wkt(3, 3, 5, 5))

  result_u <- a5_uncompact(a5_polygon_to_cells(with_hole, resolution = 6),
                           resolution = 6)
  hole_u <- a5_uncompact(a5_polygon_to_cells(hole_alone, resolution = 6),
                         resolution = 6)
  # No cell from the hole should appear in the result.
  expect_true(length(intersect(format(result_u), format(hole_u))) == 0L)
})

test_that("polygon with two holes subtracts both", {
  # Outer 0..8 with two disjoint holes.
  outer  <- wk::wkt(square_wkt(0, 0, 8, 8))
  hole_a <- wk::wkt(square_wkt(1, 1, 3, 3))
  hole_b <- wk::wkt(square_wkt(5, 5, 7, 7))
  with_holes <- wk::wkt(
    "POLYGON ((0 0, 8 0, 8 8, 0 8, 0 0),
              (1 1, 3 1, 3 3, 1 3, 1 1),
              (5 5, 7 5, 7 7, 5 7, 5 5))"
  )

  outer_u  <- a5_uncompact(a5_polygon_to_cells(outer,  resolution = 6), 6)
  hole_a_u <- a5_uncompact(a5_polygon_to_cells(hole_a, resolution = 6), 6)
  hole_b_u <- a5_uncompact(a5_polygon_to_cells(hole_b, resolution = 6), 6)
  result_u <- a5_uncompact(a5_polygon_to_cells(with_holes, resolution = 6), 6)

  expected <- setdiff(format(outer_u),
                      c(format(hole_a_u), format(hole_b_u)))
  expect_setequal(format(result_u), expected)
})

test_that("MULTIPOLYGON where one part has a hole subtracts only that hole", {
  # First part: outer 0..8 with a hole 3..5. Second part: simple 10..12 square.
  outer1 <- wk::wkt(square_wkt(0, 0, 8, 8))
  hole1  <- wk::wkt(square_wkt(3, 3, 5, 5))
  part2  <- wk::wkt(square_wkt(10, 10, 12, 12))
  mp <- wk::wkt(
    "MULTIPOLYGON (((0 0, 8 0, 8 8, 0 8, 0 0), (3 3, 5 3, 5 5, 3 5, 3 3)),
                   ((10 10, 12 10, 12 12, 10 12, 10 10)))"
  )

  outer1_u <- a5_uncompact(a5_polygon_to_cells(outer1, resolution = 6), 6)
  hole1_u  <- a5_uncompact(a5_polygon_to_cells(hole1,  resolution = 6), 6)
  part2_u  <- a5_uncompact(a5_polygon_to_cells(part2,  resolution = 6), 6)
  result_u <- a5_uncompact(a5_polygon_to_cells(mp, resolution = 6), 6)

  expected <- c(setdiff(format(outer1_u), format(hole1_u)),
                format(part2_u))
  expect_setequal(format(result_u), expected)
})

test_that("MULTIPOLYGON with holes in every part subtracts each independently", {
  outer1 <- wk::wkt(square_wkt(0, 0, 8, 8))
  hole1  <- wk::wkt(square_wkt(3, 3, 5, 5))
  outer2 <- wk::wkt(square_wkt(10, 0, 18, 8))
  hole2  <- wk::wkt(square_wkt(13, 3, 15, 5))
  mp <- wk::wkt(
    "MULTIPOLYGON (((0 0, 8 0, 8 8, 0 8, 0 0), (3 3, 5 3, 5 5, 3 5, 3 3)),
                   ((10 0, 18 0, 18 8, 10 8, 10 0), (13 3, 15 3, 15 5, 13 5, 13 3)))"
  )

  outer1_u <- a5_uncompact(a5_polygon_to_cells(outer1, resolution = 6), 6)
  hole1_u  <- a5_uncompact(a5_polygon_to_cells(hole1,  resolution = 6), 6)
  outer2_u <- a5_uncompact(a5_polygon_to_cells(outer2, resolution = 6), 6)
  hole2_u  <- a5_uncompact(a5_polygon_to_cells(hole2,  resolution = 6), 6)
  result_u <- a5_uncompact(a5_polygon_to_cells(mp, resolution = 6), 6)

  expected <- c(setdiff(format(outer1_u), format(hole1_u)),
                setdiff(format(outer2_u), format(hole2_u)))
  expect_setequal(format(result_u), expected)
})

test_that("sf MULTIPOLYGON with a hole subtracts the hole", {
  skip_if_not_installed("sf")
  outer_ring <- matrix(c(0, 0, 8, 0, 8, 8, 0, 8, 0, 0), ncol = 2, byrow = TRUE)
  hole_ring  <- matrix(c(3, 3, 5, 3, 5, 5, 3, 5, 3, 3), ncol = 2, byrow = TRUE)
  poly <- sf::st_polygon(list(outer_ring, hole_ring))
  sfc <- sf::st_sfc(poly, crs = 4326)

  outer <- wk::wkt(square_wkt(0, 0, 8, 8))
  hole  <- wk::wkt(square_wkt(3, 3, 5, 5))
  outer_u <- a5_uncompact(a5_polygon_to_cells(outer, resolution = 6), 6)
  hole_u  <- a5_uncompact(a5_polygon_to_cells(hole,  resolution = 6), 6)
  result_u <- a5_uncompact(a5_polygon_to_cells(sfc, resolution = 6), 6)

  expected <- setdiff(format(outer_u), format(hole_u))
  expect_setequal(format(result_u), expected)
})

# -- a5_linestring_to_cells ----------------------------------------------------

test_that("a5_linestring_to_cells returns ordered cells along the path", {
  line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
  cells <- a5_linestring_to_cells(line, resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) >= 2)
  start <- a5_lonlat_to_cell(2.35, 48.86, resolution = 5)
  end   <- a5_lonlat_to_cell(-0.13, 51.51, resolution = 5)
  expect_true(format(start) %in% format(cells))
  expect_true(format(end) %in% format(cells))
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

test_that("MULTILINESTRING returns the deduped union in feature order", {
  ml <- wk::wkt(
    "MULTILINESTRING ((2.35 48.86, -0.13 51.51),
                      (-0.13 51.51, 4.83 45.76))"
  )
  cells <- a5_linestring_to_cells(ml, resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_equal(length(cells), length(unique(format(cells))))
  paris  <- a5_lonlat_to_cell(2.35, 48.86, resolution = 5)
  london <- a5_lonlat_to_cell(-0.13, 51.51, resolution = 5)
  lyon   <- a5_lonlat_to_cell(4.83, 45.76, resolution = 5)
  expect_true(all(c(format(paris), format(london), format(lyon)) %in%
                  format(cells)))
})

test_that("a5_linestring_to_cells handles an antimeridian-crossing path", {
  line <- wk::wkt("LINESTRING (170 0, -170 0)")
  cells <- a5_linestring_to_cells(line, resolution = 5)
  centres <- a5_cell_to_lonlat(cells)
  lons <- wk::wk_coords(centres)$x
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
  p1 <- a5_polygon_to_cells(mp, resolution = 8)
  l1 <- a5_linestring_to_cells(ml, resolution = 5)

  a5_set_threads(2)
  p2 <- a5_polygon_to_cells(mp, resolution = 8)
  l2 <- a5_linestring_to_cells(ml, resolution = 5)

  expect_setequal(format(p1), format(p2))
  expect_identical(format(l1), format(l2))
})

# -- empty-result behaviour ---------------------------------------------------

test_that("polygon smaller than a single cell returns an empty a5_cell", {
  # A res-14 cell's pentagon is several orders of magnitude smaller than
  # any res-8 cell, so no res-8 centre can lie inside it.
  tiny <- a5_cell_to_boundary(a5_lonlat_to_cell(10, 50, resolution = 14))
  out <- a5_polygon_to_cells(tiny, resolution = 8)
  expect_s3_class(out, "a5_cell")
  expect_length(out, 0L)
})

# -- input validation: polygon -------------------------------------------------

test_that("polygon matrix input must have exactly 2 columns", {
  expect_error(
    a5_polygon_to_cells(matrix(0, nrow = 4, ncol = 3), resolution = 8),
    "exactly 2 columns"
  )
  expect_error(
    a5_polygon_to_cells(matrix(0, nrow = 4, ncol = 1), resolution = 8),
    "exactly 2 columns"
  )
})

test_that("polygon matrix input must be numeric", {
  m <- matrix(c("a", "b", "c", "d", "e", "f"), ncol = 2)
  expect_error(
    a5_polygon_to_cells(m, resolution = 8),
    "must be numeric"
  )
})

test_that("polygon data.frame input must have lon and lat columns", {
  expect_error(
    a5_polygon_to_cells(data.frame(x = 1:3, y = 1:3), resolution = 8),
    "lon.*lat"
  )
  expect_error(
    a5_polygon_to_cells(data.frame(lon = 1:3), resolution = 8),
    "lon.*lat"
  )
})

test_that("polygon vertex count is enforced", {
  expect_error(
    a5_polygon_to_cells(matrix(c(0, 0, 1, 1), ncol = 2), resolution = 8),
    "at least 3 vertices"
  )
})

test_that("polygon NA coordinates error", {
  expect_error(
    a5_polygon_to_cells(
      data.frame(lon = c(0, 1, NA, 0), lat = c(0, 0, 1, 0)),
      resolution = 8
    ),
    "NA"
  )
  expect_error(
    a5_polygon_to_cells(
      matrix(c(0, 1, NA, 0, 0, 0, 1, 0), ncol = 2),
      resolution = 8
    ),
    "NA"
  )
})

test_that("polygon rejects wrong geometry types", {
  expect_error(
    a5_polygon_to_cells(wk::wkt("POINT (0 0)"), resolution = 8),
    "POLYGON"
  )
  expect_error(
    a5_polygon_to_cells(wk::wkt("LINESTRING (0 0, 1 1)"), resolution = 8),
    "POLYGON"
  )
})

test_that("polygon rejects empty geometries", {
  expect_error(
    a5_polygon_to_cells(wk::wkt("POLYGON EMPTY"), resolution = 8),
    "empty geometries"
  )
})

test_that("polygon rejects empty sfc / wkt vector", {
  expect_error(
    a5_polygon_to_cells(wk::wkt(character()), resolution = 8),
    "no polygon rings"
  )
})

test_that("polygon rejects non-geometry input", {
  # A plain list isn't wk-handleable.
  expect_error(
    a5_polygon_to_cells(list(a = 1, b = 2), resolution = 8),
    "Could not interpret"
  )
})

# -- input validation: linestring ---------------------------------------------

test_that("linestring matrix input must have exactly 2 columns", {
  expect_error(
    a5_linestring_to_cells(matrix(0, nrow = 4, ncol = 3), resolution = 8),
    "exactly 2 columns"
  )
})

test_that("linestring matrix input must be numeric", {
  m <- matrix(c("a", "b", "c", "d"), ncol = 2)
  expect_error(
    a5_linestring_to_cells(m, resolution = 8),
    "must be numeric"
  )
})

test_that("linestring data.frame input must have lon and lat columns", {
  expect_error(
    a5_linestring_to_cells(data.frame(x = 1:3, y = 1:3), resolution = 8),
    "lon.*lat"
  )
})

test_that("linestring vertex count is enforced", {
  expect_error(
    a5_linestring_to_cells(matrix(c(0, 0), ncol = 2), resolution = 8),
    "at least 2 vertices"
  )
})

test_that("linestring NA coordinates error", {
  expect_error(
    a5_linestring_to_cells(
      data.frame(lon = c(0, NA, 1), lat = c(0, 0, 1)),
      resolution = 8
    ),
    "NA"
  )
  expect_error(
    a5_linestring_to_cells(
      matrix(c(0, NA, 1, 0, 0, 1), ncol = 2),
      resolution = 8
    ),
    "NA"
  )
})

test_that("linestring rejects wrong geometry types", {
  expect_error(
    a5_linestring_to_cells(wk::wkt("POINT (0 0)"), resolution = 8),
    "LINESTRING"
  )
  expect_error(
    a5_linestring_to_cells(
      wk::wkt(square_wkt(0, 0, 1, 1)),
      resolution = 8
    ),
    "LINESTRING"
  )
})

test_that("linestring rejects empty geometries", {
  expect_error(
    a5_linestring_to_cells(wk::wkt("LINESTRING EMPTY"), resolution = 8),
    "empty geometries"
  )
})

test_that("linestring rejects empty sfc / wkt vector", {
  expect_error(
    a5_linestring_to_cells(wk::wkt(character()), resolution = 8),
    "no linestrings"
  )
})

test_that("linestring rejects non-geometry input", {
  expect_error(
    a5_linestring_to_cells(list(a = 1, b = 2), resolution = 8),
    "Could not interpret"
  )
})

# -- input validation: shared ------------------------------------------------

test_that("resolution must be in 0..30", {
  poly <- wk::wkt(square_wkt(0, 0, 1, 1))
  line <- wk::wkt("LINESTRING (0 0, 1 1)")
  expect_error(a5_polygon_to_cells(poly, resolution = -1), "resolution")
  expect_error(a5_polygon_to_cells(poly, resolution = 31), "resolution")
  expect_error(a5_linestring_to_cells(line, resolution = -1), "resolution")
  expect_error(a5_linestring_to_cells(line, resolution = 31), "resolution")
})

test_that("resolution must be scalar", {
  poly <- wk::wkt(square_wkt(0, 0, 1, 1))
  line <- wk::wkt("LINESTRING (0 0, 1 1)")
  expect_error(a5_polygon_to_cells(poly, resolution = c(5, 6)), "size 1")
  expect_error(a5_linestring_to_cells(line, resolution = c(5, 6)), "size 1")
})
