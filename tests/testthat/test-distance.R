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

test_that("cell_distance with units = NULL returns plain numeric in metres", {
  a <- a5_lonlat_to_cell(0, 0, resolution = 8)
  b <- a5_lonlat_to_cell(1, 1, resolution = 8)
  d_null <- a5_cell_distance(a, b, units = NULL)
  d_m <- a5_cell_distance(a, b, units = "m")
  expect_type(d_null, "double")
  expect_false(inherits(d_null, "units"))
  expect_equal(d_null, as.numeric(d_m))
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

# -- regression: distances match the geo-crate reference (pre-geographiclib-rs swap) --

test_that("cell_distance reproduces reference values across methods", {
  from <- a5_cell(c(
    "4f05dce800000000",
    "4f05dce800000000",
    "6344b9a800000000",
    "63c20d0800000000",
    "636119e800000000",
    "99ffbd8800000000",
    "9994b2c800000000",
    "0d7e51a800000000",
    "03102db800000000",
    "a519956800000000",
    "e45b840800000000",
    "e45beb8800000000"
  ))
  to <- a5_cell(c(
    "4f05dce800000000",
    "6344b9a800000000",
    "63c20d0800000000",
    "636119e800000000",
    "99ffbd8800000000",
    "9994b2c800000000",
    "0d7e51a800000000",
    "03102db800000000",
    "a519956800000000",
    "e45b840800000000",
    "e45beb8800000000",
    "4f05dce800000000"
  ))
  expected_haversine <- c(
    0.0000000000,
    6223089.3225855026,
    868976.0884353485,
    343575.6233557399,
    18764156.8127482198,
    884130.4792613365,
    16004250.8897330742,
    3288969.3920196095,
    11804973.4756475873,
    8902912.3808900733,
    21298.6234844250,
    20004743.4530832879
  )
  expect_equal(as.numeric(a5_cell_distance(from, to, method = "haversine")),
               expected_haversine, tolerance = 1e-6)
  expected_geodesic <- c(
    0.0000000000,
    6204756.3231073171,
    870002.0993081998,
    343942.0480297675,
    18754902.1735365540,
    886016.0406684305,
    15984752.9018089883,
    3302728.0615876373,
    11798145.1055286042,
    8912243.1546909939,
    21322.2966376381,
    20002301.3520815559
  )
  expect_equal(as.numeric(a5_cell_distance(from, to, method = "geodesic")),
               expected_geodesic, tolerance = 1e-6)
  expected_rhumb <- c(
    0.0000000000,
    6223302.5609158203,
    869190.0588820956,
    343591.4463332743,
    19876406.6116701961,
    884643.8622704616,
    18756157.0486545265,
    4566582.2271785056,
    12610547.7283295486,
    8910117.7815931886,
    21298.6234844447,
    20004778.0667438693
  )
  expect_equal(as.numeric(a5_cell_distance(from, to, method = "rhumb")),
               expected_rhumb, tolerance = 1e-6)
})
