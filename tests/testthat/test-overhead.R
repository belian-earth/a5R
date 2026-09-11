# The fast paths added for per-call performance must be invisible to users:
# every result and error here is compared against the general (vctrs / units /
# wk) construction it replaces.

test_that("lonlat_to_cell fast path matches the vctrs path", {
  lon <- c(139.7, -3.19, 0)
  lat <- c(35.69, 55.95, 0)
  expect_identical(
    a5_lonlat_to_cell(lon, lat, 12),
    a5_lonlat_to_cell(lon, lat, 12L)
  )
  expect_identical(
    a5_lonlat_to_cell(lon, lat, c(5, 6, 7)),
    a5_lonlat_to_cell(lon, lat, c(5L, 6L, 7L))
  )
  # Names are carried through vctrs and ignored by Rust either way.
  expect_identical(
    a5_lonlat_to_cell(c(a = 139.7), c(b = 35.69), 12),
    a5_lonlat_to_cell(139.7, 35.69, 12L)
  )
  # Scalar lat recycles against vector lon (vctrs path).
  expect_identical(
    a5_lonlat_to_cell(lon, 0, 5),
    a5_lonlat_to_cell(lon, c(0, 0, 0), 5L)
  )
  expect_true(is.na(a5_lonlat_to_cell(0, 0, NA)))
})

test_that("lonlat_to_cell rejects what vctrs rejects", {
  expect_error(a5_lonlat_to_cell(matrix(c(1, 2, 3, 4), 2), 0, 5), "dimensionality")
  expect_error(a5_lonlat_to_cell(0, 0, matrix(5, 1)), "dimensionality")
  expect_error(a5_lonlat_to_cell("a", 0, 5), "character")
  expect_error(a5_lonlat_to_cell(0, 0, 12.5), "precision")
  expect_error(a5_lonlat_to_cell(0, 0, Inf), "precision")
  expect_error(a5_lonlat_to_cell(1:2 + 0, 1:3 + 0, 5), "recycle")
  expect_error(a5_lonlat_to_cell(units::set_units(1, "degrees"), 0, 5))
})

test_that("check_size1 reports like vctrs::vec_assert", {
  expect_error(a5_grid_disk(a5_lonlat_to_cell(c(0, 1), c(0, 1), 5), k = 1), "size 1")
  expect_error(a5_cell_to_children(a5_lonlat_to_cell(0, 0, 5), resolution = c(6, 7)), "`resolution` must have size 1, not size 2")
  expect_error(a5_set_threads(1:2), "size 1")
})

test_that("units fast path matches units::set_units", {
  r <- a5_cell_area(5L, units = NULL)
  expect_identical(a5_cell_area(5L), units::set_units(r, "m^2", mode = "standard"))
  expect_identical(
    a5_cell_area(5L, units = "km^2"),
    units::set_units(units::set_units(r, "m^2", mode = "standard"), "km^2", mode = "standard")
  )
  e <- a5_cell_edge_length_avg(5L, units = NULL)
  expect_identical(a5_cell_edge_length_avg(5L), units::set_units(e, "m", mode = "standard"))
  expect_identical(
    a5_cell_edge_length_avg(5L, units = "km"),
    units::set_units(units::set_units(e, "m", mode = "standard"), "km", mode = "standard")
  )
  a <- a5_lonlat_to_cell(0, 0, 5)
  b <- a5_lonlat_to_cell(1, 1, 5)
  d <- a5_cell_distance(a, b, units = NULL)
  expect_identical(a5_cell_distance(a, b), units::set_units(d, "m", mode = "standard"))
  expect_error(a5_cell_area(5L, units = "km"), "area unit")
  expect_error(a5_cell_edge_length_avg(5L, units = "km^2"), "length unit")
  expect_error(a5_cell_distance(a, b, units = "m^2"), "distance unit")
})

test_that("cell_to_lonlat constructors match wk::xy and data.frame", {
  cells <- a5_lonlat_to_cell(c(139.7, -3.19), c(35.69, 55.95), 8L)
  ll <- a5_cell_to_lonlat(cells, as_dataframe = TRUE)
  expect_identical(ll, data.frame(lon = ll$lon, lat = ll$lat))
  expect_identical(
    a5_cell_to_lonlat(cells),
    wk::xy(ll$lon, ll$lat, crs = wk::wk_crs_longlat())
  )
})

test_that("default and explicit choice arguments agree", {
  cell <- a5_lonlat_to_cell(139.7, 35.69, 8L)
  expect_identical(a5_cell_to_boundary(cell), a5_cell_to_boundary(cell, format = "wkb"))
  expect_error(a5_cell_to_boundary(cell, format = "geojson"), "must be one of")
  poly <- wk::wkt("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))")
  expect_identical(a5_polygon_to_cells(poly, 6L), a5_polygon_to_cells(poly, 6L, containment = "centre"))
  a <- a5_lonlat_to_cell(0, 0, 5)
  b <- a5_lonlat_to_cell(1, 1, 5)
  expect_identical(a5_cell_distance(a, b), a5_cell_distance(a, b, method = "haversine"))
  expect_error(a5_cell_distance(a, b, method = "euclid"), "must be one of")
})
