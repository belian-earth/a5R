test_that("lonlat_to_cell returns a5_cell", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
  expect_s3_class(cell, "a5_cell")
  expect_length(cell, 1L)
})

test_that("round-trip lonlat -> cell -> lonlat is stable", {
  lon <- -3.19
  lat <- 55.95
  cell <- a5_lonlat_to_cell(lon, lat, resolution = 15)
  pt <- a5_cell_to_lonlat(cell)
  expect_equal(wk::wk_coords(pt)$x, lon, tolerance = 0.01)
  expect_equal(wk::wk_coords(pt)$y, lat, tolerance = 0.01)
})

test_that("vectorised indexing works", {
  lons <- c(-3.19, 0, 140)
  lats <- c(55.95, 0, 35.68)
  cells <- a5_lonlat_to_cell(lons, lats, resolution = 5)
  expect_length(cells, 3L)
  expect_s3_class(cells, "a5_cell")
})

test_that("NA handling in lonlat_to_cell", {
  cell <- a5_lonlat_to_cell(NA_real_, 55.95, resolution = 5)
  expect_true(is.na(vctrs::vec_data(cell)))
})
