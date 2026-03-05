# -- a5_cell_distance ----------------------------------------------------------

test_that("cell_distance returns units vector in metres", {
  a <- a5_lonlat_to_cell(0, 0, resolution = 8)
  b <- a5_lonlat_to_cell(1, 1, resolution = 8)
  d <- a5_cell_distance(a, b)
  expect_s3_class(d, "units")
  expect_equal(units::deparse_unit(d), "m")
  expect_true(d > units::set_units(0, "m"))
})

test_that("cell_distance of a cell to itself is zero", {
  cell <- a5_lonlat_to_cell(10, 50, resolution = 10)
  d <- a5_cell_distance(cell, cell)
  expect_equal(as.numeric(d), 0)
})

test_that("cell_distance supports unit conversion", {
  a <- a5_lonlat_to_cell(0, 0, resolution = 8)
  b <- a5_lonlat_to_cell(1, 1, resolution = 8)
  d_m <- a5_cell_distance(a, b)
  d_km <- a5_cell_distance(a, b, units = "km")
  expect_equal(as.numeric(d_km), as.numeric(d_m) / 1000, tolerance = 1e-10)
})

test_that("cell_distance is vectorised and recycled", {
  origin <- a5_lonlat_to_cell(0, 0, resolution = 8)
  targets <- a5_lonlat_to_cell(c(1, 2, 3), c(1, 2, 3), resolution = 8)
  d <- a5_cell_distance(origin, targets)
  expect_length(d, 3L)
  # distances should be increasing
  expect_true(all(diff(as.numeric(d)) > 0))
  e <- a5_cell_distance(targets, origin)
  expect_equal(as.numeric(d), as.numeric(e))
})

test_that("cell_distance handles NA", {
  a <- a5_lonlat_to_cell(0, 0, resolution = 8)
  d <- a5_cell_distance(a, a5_cell(NA))
  expect_true(is.na(d))
})

test_that("cell_distance is close to s2/sf", {
  skip_if_not_installed("sf")
  uses2 <- sf::sf_use_s2(TRUE)
  withr::defer(sf::sf_use_s2(uses2))

  a <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
  b <- a5_lonlat_to_cell(-2.0, 55.0, resolution = 10)
  d <- as.numeric(a5_cell_distance(a, b))

  p1 <- sf::st_sfc(sf::st_point(as.numeric(a5_cell_to_lonlat(a))), crs = 4326)
  p2 <- sf::st_sfc(sf::st_point(as.numeric(a5_cell_to_lonlat(b))), crs = 4326)

  sf_d <- as.numeric(sf::st_distance(p1, p2))

  expect_equal(d, sf_d, tolerance = 0.1) # within 1 metre.
})

test_that("cell_distance rejects invalid units", {
  a <- a5_lonlat_to_cell(0, 0, resolution = 8)
  expect_error(a5_cell_distance(a, a, units = "kg"), "distance unit")
})

test_that("cell_distance default method is haversine", {
  a <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
  b <- a5_lonlat_to_cell(-2.0, 55.0, resolution = 8)
  d_default <- as.numeric(a5_cell_distance(a, b))
  d_explicit <- as.numeric(a5_cell_distance(a, b, method = "haversine"))
  expect_equal(d_default, d_explicit)
})

test_that("cell_distance geodesic is close to haversine", {
  a <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
  b <- a5_lonlat_to_cell(-2.0, 55.0, resolution = 8)
  d_hav <- as.numeric(a5_cell_distance(a, b, method = "haversine"))
  d_geo <- as.numeric(a5_cell_distance(a, b, method = "geodesic"))

  # Geodesic distance should be greater than or equal to haversine (great circle) distance
  expect_gte(d_geo, d_hav)
  # But equal within 0.3% of each other
  expect_equal(d_geo, d_hav, tolerance = 0.003)
})

test_that("cell_distance rhumb >= haversine (great circle)", {
  a <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
  b <- a5_lonlat_to_cell(-2.0, 55.0, resolution = 8)
  d_hav <- as.numeric(a5_cell_distance(a, b, method = "haversine"))
  d_rhumb <- as.numeric(a5_cell_distance(a, b, method = "rhumb"))
  expect_true(d_rhumb >= d_hav)
})

test_that("cell_distance rejects invalid method", {
  a <- a5_lonlat_to_cell(0, 0, resolution = 8)
  expect_error(a5_cell_distance(a, a, method = "euclidean"), "must be one of")
})
