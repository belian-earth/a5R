# -- helpers -------------------------------------------------------------------

square_wkt <- function(xmin, ymin, xmax, ymax) {
  sprintf(
    "POLYGON ((%s %s, %s %s, %s %s, %s %s, %s %s))",
    xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin
  )
}

# -- a5_polygon_to_cells: return type ------------------------------------------

test_that("a5_polygon_to_cells returns one covering", {
  poly <- wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5))
  covering <- a5_polygon_to_cells(poly, resolution = 10)
  expect_s3_class(covering, "a5_covering")
  expect_length(covering, 1L)
  expect_identical(a5_covering_resolution(covering), 10L)
  expect_true(a5_is_valid(covering))
  cells <- a5_uncompact(covering)
  expect_gt(length(cells), 0L)
  expect_true(all(a5_get_resolution(cells) == 10L))
  expect_false(anyDuplicated(cells) > 0)
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
  expect_identical(cells_m, cells_w)
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
  expect_identical(cells_df, cells_w)
})

test_that("a5_polygon_to_cells accepts wk::rct", {
  rect_cells <- a5_polygon_to_cells(wk::rct(-3.5, 55.5, -2.5, 56.5),
                                    resolution = 10)
  wkt_cells <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_identical(rect_cells, wkt_cells)
})

test_that("a5_polygon_to_cells accepts a terra SpatVector", {
  skip_if_not_installed("terra")
  sv <- terra::vect(square_wkt(-3.5, 55.5, -2.5, 56.5))
  cells_terra <- a5_polygon_to_cells(sv, resolution = 10)
  cells_w <- a5_polygon_to_cells(
    wk::wkt(square_wkt(-3.5, 55.5, -2.5, 56.5)),
    resolution = 10
  )
  expect_identical(cells_terra, cells_w)
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
  expect_identical(cells_terra, cells_w)
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
  expect_identical(cells_sf, cells_w)
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

test_that("sfc of multiple polygons gives one covering per feature", {
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
  coverings <- a5_polygon_to_cells(sfc, resolution = 8)
  expect_s3_class(coverings, "a5_covering")
  expect_length(coverings, 2L)
  expect_identical(coverings[1], a5_polygon_to_cells(sfc[1], resolution = 8))
  expect_identical(coverings[2], a5_polygon_to_cells(sfc[2], resolution = 8))

  # an sf data frame gets a column
  df <- sf::st_sf(id = 1:2, geometry = sfc)
  df$cells <- a5_polygon_to_cells(df, resolution = 8)
  expect_identical(df$cells, coverings)
})

test_that("each feature keeps its own covering, with NA and empty geometries", {
  polys <- wk::wkt(c(
    square_wkt(-3.5, 55.5, -2.5, 56.5),
    NA,
    "POLYGON EMPTY",
    "MULTIPOLYGON (((0 0, 2 0, 2 2, 0 2, 0 0)), ((5 5, 7 5, 7 7, 5 7, 5 5)))",
    square_wkt(1, 1, 2, 2)
  ))
  out <- a5_polygon_to_cells(polys, resolution = 8)
  expect_length(out, 5L)
  expect_identical(is.na(out), c(FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(lengths(a5_uncompact(out, simplify = FALSE))[3], 0L)
  expect_identical(a5_covering_resolution(out[3]), 8L)
  for (i in c(1L, 4L, 5L)) {
    expect_identical(out[i], a5_polygon_to_cells(polys[i], resolution = 8))
  }
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

test_that("MULTILINESTRING parts join into one deduplicated path", {
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

  lines <- wk::wkt(c(as.character(ml), "LINESTRING (2.35 48.86, 13.4 52.52)"))

  a5_set_threads(1)
  p1 <- a5_polygon_to_cells(mp, resolution = 8)
  l1 <- a5_linestring_to_cells(ml, resolution = 5)
  f1 <- a5_linestring_to_cells(lines, resolution = 5, simplify = FALSE)

  a5_set_threads(2)
  p2 <- a5_polygon_to_cells(mp, resolution = 8)
  l2 <- a5_linestring_to_cells(ml, resolution = 5)
  f2 <- a5_linestring_to_cells(lines, resolution = 5, simplify = FALSE)

  expect_identical(p1, p2)
  expect_identical(l1, l2)
  expect_identical(f1, f2)
})

# -- empty-result behaviour ---------------------------------------------------

test_that("polygon smaller than a single cell gives an empty covering", {
  # A res-14 cell's pentagon is several orders of magnitude smaller than
  # any res-8 cell, so no res-8 centre can lie inside it.
  tiny <- a5_cell_to_boundary(a5_lonlat_to_cell(10, 50, resolution = 14))
  out <- a5_polygon_to_cells(tiny, resolution = 8)
  expect_s3_class(out, "a5_covering")
  expect_length(out, 1L)
  expect_false(is.na(out))
  expect_length(a5_uncompact(out), 0L)
  expect_identical(a5_covering_resolution(out), 8L)
})

# -- input validation: polygon -------------------------------------------------

test_that("polygon matrix and data.frame input must have vertices", {
  expect_error(
    a5_polygon_to_cells(matrix(numeric(), ncol = 2), resolution = 8),
    "no polygon rings"
  )
  expect_error(
    a5_polygon_to_cells(data.frame(lon = numeric(), lat = numeric()), resolution = 8),
    "no polygon rings"
  )
})

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

test_that("an empty geometry gives an empty covering", {
  out <- a5_polygon_to_cells(wk::wkt("POLYGON EMPTY"), resolution = 8)
  expect_length(out, 1L)
  expect_false(is.na(out))
  expect_length(a5_uncompact(out), 0L)
})

test_that("an empty geometry vector gives an empty covering vector", {
  out <- a5_polygon_to_cells(wk::wkt(character()), resolution = 8)
  expect_s3_class(out, "a5_covering")
  expect_length(out, 0L)
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

test_that("linestring empty and missing geometries contribute no cells", {
  expect_length(a5_linestring_to_cells(wk::wkt("LINESTRING EMPTY"), resolution = 8), 0L)
  expect_length(a5_linestring_to_cells(wk::wkt(character()), resolution = 8), 0L)
  lst <- a5_linestring_to_cells(
    wk::wkt(c("LINESTRING (2.35 48.86, -0.13 51.51)", NA, "LINESTRING EMPTY")),
    resolution = 5, simplify = FALSE
  )
  expect_identical(lengths(lst)[2:3], c(0L, 0L))
  expect_gt(lengths(lst)[1], 0L)
  expect_error(
    a5_linestring_to_cells(matrix(numeric(), ncol = 2), resolution = 8),
    "no linestrings"
  )
})

test_that("linestrings give one ordered path per feature", {
  lines <- wk::wkt(c(
    "LINESTRING (2.35 48.86, -0.13 51.51)",
    "LINESTRING (2.35 48.86, 4.83 45.76)",
    "MULTILINESTRING ((2.35 48.86, -0.13 51.51), (-0.13 51.51, 4.83 45.76))"
  ))
  paths <- a5_linestring_to_cells(lines, resolution = 5, simplify = FALSE)
  expect_s3_class(paths, "a5_cell_list")
  expect_length(paths, 3L)
  for (i in 1:3) {
    expect_identical(paths[[i]], a5_linestring_to_cells(lines[i], resolution = 5))
  }
  # flat form: the paths concatenated, so the shared Paris cell appears twice
  flat <- a5_linestring_to_cells(lines[1:2], resolution = 5)
  expect_identical(flat, vctrs::list_unchop(paths[1:2]))
  paris <- a5_lonlat_to_cell(2.35, 48.86, resolution = 5)
  expect_identical(sum(flat == paris), 2L)
  # within a feature, parts are joined in order and each cell kept once
  expect_false(anyDuplicated(paths[[3]]) > 0)
  expect_identical(paths[[3]][seq_along(paths[[1]])], paths[[1]])
  expect_error(a5_linestring_to_cells(lines, 5, simplify = NA), "TRUE")
})

test_that("linestring paths fill a list column of an sf data frame", {
  skip_if_not_installed("sf")
  df <- sf::st_sf(
    id = 1:2,
    geometry = sf::st_as_sfc(c(
      "LINESTRING (2.35 48.86, -0.13 51.51)",
      "LINESTRING (2.35 48.86, 4.83 45.76)"
    ), crs = 4326)
  )
  df$path <- a5_linestring_to_cells(df, resolution = 5, simplify = FALSE)
  expect_s3_class(df$path, "a5_cell_list")
  expect_identical(df$path[[2]], a5_linestring_to_cells(df[2, ], resolution = 5))
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

# -- containment ---------------------------------------------------------------

test_that("containment = 'overlapping' is a superset of the centre result", {
  poly <- wk::wkt(square_wkt(-3.3, 55.9, -3.1, 56.0))
  centre <- a5_uncompact(a5_polygon_to_cells(poly, 10), 10)
  overlap <- a5_uncompact(
    a5_polygon_to_cells(poly, 10, containment = "overlapping"), 10
  )
  expect_s3_class(overlap, "a5_cell")
  expect_true(length(overlap) > length(centre))
  expect_true(all(format(centre) %in% format(overlap)))
})

test_that("containment = 'overlapping' includes cells straddling the boundary", {
  poly <- wk::wkt(square_wkt(-3.3, 55.9, -3.1, 56.0))
  overlap <- a5_uncompact(
    a5_polygon_to_cells(poly, 12, containment = "overlapping"), 12
  )
  # Every polygon vertex lies on the boundary, so its cell must be present.
  corner_cells <- a5_lonlat_to_cell(
    c(-3.3, -3.1, -3.1, -3.3), c(55.9, 55.9, 56.0, 56.0), 12
  )
  expect_true(all(format(corner_cells) %in% format(overlap)))
})

test_that("containment = 'overlapping' still excludes hole interiors", {
  outer <- "(-3.4 55.8, -3.0 55.8, -3.0 56.1, -3.4 56.1, -3.4 55.8)"
  hole <- "(-3.25 55.9, -3.15 55.9, -3.15 56.0, -3.25 56.0, -3.25 55.9)"
  poly <- wk::wkt(sprintf("POLYGON (%s, %s)", outer, hole))
  overlap <- a5_uncompact(
    a5_polygon_to_cells(poly, 12, containment = "overlapping"), 12
  )
  hole_centre <- a5_lonlat_to_cell(-3.2, 55.95, 12)
  expect_false(format(hole_centre) %in% format(overlap))
  # but a cell on the hole edge is kept
  hole_edge <- a5_lonlat_to_cell(-3.25, 55.95, 12)
  expect_true(format(hole_edge) %in% format(overlap))
})

test_that("containment = 'overlapping' works for multi-part input", {
  skip_if_not_installed("sf")
  sq1 <- sf::st_polygon(list(rbind(
    c(-3.5, 55.5), c(-3.0, 55.5), c(-3.0, 56.0), c(-3.5, 56.0), c(-3.5, 55.5)
  )))
  sq2 <- sf::st_polygon(list(rbind(
    c(-2.5, 55.5), c(-2.0, 55.5), c(-2.0, 56.0), c(-2.5, 56.0), c(-2.5, 55.5)
  )))
  multi <- sf::st_sfc(sq1, sq2, crs = 4326)
  each <- unique(c(
    format(a5_uncompact(a5_polygon_to_cells(sf::st_sfc(sq1, crs = 4326), 10,
                                            containment = "overlapping"), 10)),
    format(a5_uncompact(a5_polygon_to_cells(sf::st_sfc(sq2, crs = 4326), 10,
                                            containment = "overlapping"), 10))
  ))
  both <- format(a5_uncompact(
    a5_polygon_to_cells(multi, 10, containment = "overlapping"), 10
  ))
  expect_setequal(both, each)
})

test_that("containment defaults to 'centre'", {
  poly <- wk::wkt(square_wkt(-3.3, 55.9, -3.1, 56.0))
  expect_identical(
    format(a5_polygon_to_cells(poly, 10, containment = "centre")),
    format(a5_polygon_to_cells(poly, 10))
  )
})

test_that("containment rejects invalid values", {
  poly <- wk::wkt(square_wkt(-3.3, 55.9, -3.1, 56.0))
  expect_error(
    a5_polygon_to_cells(poly, 10, containment = "bogus"),
    "containment"
  )
  expect_error(
    a5_polygon_to_cells(poly, 10, containment = "center"),
    "centre"
  )
  expect_error(
    a5_polygon_to_cells(poly, 10, containment = 1),
    "containment"
  )
  expect_error(
    a5_polygon_to_cells(poly, 10, containment = c("centre", "centre")),
    "containment"
  )
})

test_that("a whole-globe rct gives every cell", {
  globe <- wk::rct(-180, -90, 180, 90)
  for (res in c(0L, 3L)) {
    expect_identical(a5_count(a5_polygon_to_cells(globe, res)), a5_get_num_cells(res))
    expect_identical(
      a5_count(a5_polygon_to_cells(globe, res, containment = "overlapping")),
      a5_get_num_cells(res)
    )
  }
})

test_that("a pole-to-pole rct keeps its edges on their meridians", {
  lune <- a5_polygon_to_cells(wk::rct(0, -90, 90, 90), 3)
  inner <- a5_polygon_to_cells(wk::rct(0, -89.99, 90, 89.99), 3)
  # a quarter of the globe, with cells of the near-pole box included
  expect_true(all(a5_contains(lune, a5_uncompact(inner))))
  expect_lt(abs(a5_count(lune) - a5_get_num_cells(3) / 4), 10)
})

test_that("ordinary rct boxes match their polygons", {
  boxes <- wk::rct(c(-60, 10), c(-30, 40), c(60, 20), c(30, 50))
  expect_identical(
    a5_polygon_to_cells(boxes, 5),
    a5_polygon_to_cells(wk::as_wkb(boxes), 5)
  )
})

test_that("rct results keep input order around whole-globe and NA boxes", {
  boxes <- wk::rct(
    c(-180, 0, NA, -180),
    c(-90, 0, NA, -90),
    c(180, 10, NA, 180),
    c(90, 10, NA, 90)
  )
  out <- a5_polygon_to_cells(boxes, 3)
  expect_length(out, 4L)
  expect_identical(a5_count(out[c(1, 4)]), rep(a5_get_num_cells(3), 2))
  expect_identical(out[2], a5_polygon_to_cells(boxes[2], 3))
  expect_identical(a5_count(out[3]), 0)
})

test_that("rct boxes 180 degrees wide or more are refused", {
  expect_error(a5_polygon_to_cells(wk::rct(-100, -60, 100, 60), 3), "200 degrees")
  expect_error(a5_polygon_to_cells(wk::rct(-180, -60, 180, 60), 3), "Split it")
})

test_that("projected input is rejected", {
  skip_if_not_installed("sf")
  poly <- sf::st_sfc(
    sf::st_polygon(list(cbind(c(0, 1e5, 1e5, 0, 0), c(0, 0, 1e5, 1e5, 0)))),
    crs = 3857
  )
  expect_error(a5_polygon_to_cells(poly, 4), "longitude/latitude coordinates")
  line <- sf::st_sfc(sf::st_linestring(cbind(c(0, 1e5), c(0, 1e5))), crs = 3857)
  expect_error(a5_linestring_to_cells(line, 4), "longitude/latitude coordinates")
  # no CRS: the coordinate range still catches it
  expect_error(a5_polygon_to_cells(sf::st_set_crs(poly, NA), 4), "outside the longitude/latitude range")
  expect_no_error(a5_polygon_to_cells(sf::st_transform(poly, 4326), 4))
})

test_that("coordinates outside the lon/lat range are rejected", {
  expect_error(
    a5_polygon_to_cells(wk::wkt("POLYGON ((0 0, 1 0, 1 95, 0 0))"), 4),
    "outside the longitude/latitude range"
  )
  expect_error(
    a5_linestring_to_cells(wk::wkt("LINESTRING (0 0, 400 0)"), 4),
    "outside the longitude/latitude range"
  )
})
