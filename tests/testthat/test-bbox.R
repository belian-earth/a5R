rct_values <- function(x) unname(unlist(unclass(x)))

test_that("edges bowing toward the pole widen the latitude range", {
  poly <- wk::wkt("POLYGON ((-30 50, 30 50, 30 60, -30 60, -30 50))")
  b <- rct_values(a5_bbox(poly))
  expect_equal(b[c(1, 3)], c(-30, 30))
  expect_equal(b[2], 50, tolerance = 1e-9)
  # atan(tan(60) / cos(30)) = atan(2) on the sphere; within 0.2 degrees of it
  # after the authalic conversion
  expect_gt(b[4], 63.2)
  expect_lt(b[4], 63.7)
  expect_identical(wk::wk_crs(a5_bbox(poly)), wk::wk_crs_longlat())
})

test_that("every cell centre inside a polygon lies in its box", {
  polys <- wk::wkt(c(
    "POLYGON ((-30 50, 30 50, 30 60, -30 60, -30 50))",
    "POLYGON ((100 -40, 150 -40, 150 -20, 100 -20, 100 -40))",
    "POLYGON ((-20 -5, 20 -5, 20 5, -20 5, -20 -5))"
  ))
  boxes <- a5_bbox(polys)
  for (i in seq_along(polys)) {
    inside <- a5_polygon_to_cells(polys[i], 5, containment = "centre")
    ll <- a5_cell_to_lonlat(a5_uncompact(inside), as_dataframe = TRUE)
    b <- rct_values(boxes[i])
    expect_true(all(ll$lon >= b[1] & ll$lon <= b[3]))
    expect_true(all(ll$lat >= b[2] & ll$lat <= b[4]))
  }
})

test_that("boxes crossing the antimeridian continue past 180", {
  poly <- wk::wkt("POLYGON ((170 -10, -170 -10, -170 10, 170 10, 170 -10))")
  b <- rct_values(a5_bbox(poly))
  expect_equal(b[c(1, 3)], c(170, 190))
  # parts on either side combine over the shorter way round
  mp <- wk::wkt("MULTIPOLYGON (((175 0, 179 0, 179 1, 175 0)), ((-179 0, -175 0, -175 1, -179 0)))")
  expect_equal(rct_values(a5_bbox(mp))[c(1, 3)], c(175, 185))
})

test_that("a ring around a pole reaches the pole on all longitudes", {
  south <- wk::wkt("POLYGON ((0 -10, 120 -10, -120 -10, 0 -10))")
  expect_equal(rct_values(a5_bbox(south)), c(-180, -90, 180, -10), tolerance = 1e-9)
  north <- wk::wkt("POLYGON ((0 70, 120 70, -120 70, 0 70))")
  expect_equal(rct_values(a5_bbox(north))[c(1, 3, 4)], c(-180, 180, 90))
})

test_that("missing geometries give NA boxes; matrix input works", {
  b <- a5_bbox(wk::wkt(c("POLYGON ((0 0, 1 0, 1 1, 0 0))", NA)))
  expect_true(all(is.na(rct_values(b[2]))))
  m <- cbind(c(0, 10, 10, 0), c(0, 0, 10, 10))
  expect_equal(rct_values(a5_bbox(m))[c(1, 3)], c(0, 10))
})

test_that("wk_rct boxes are polygons with great-circle edges", {
  b <- rct_values(a5_bbox(wk::rct(-30, 50, 30, 60)))
  expect_equal(b[c(1, 2, 3)], c(-30, 50, 30), tolerance = 1e-9)
  expect_gt(b[4], 63)
})
