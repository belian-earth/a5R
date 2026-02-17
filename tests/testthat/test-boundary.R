test_that("cell_to_boundary returns wk_wkt polygons", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
  boundary <- a5_cell_to_boundary(cell)
  expect_s3_class(boundary, "wk_wkt")
  expect_length(boundary, 1L)
  expect_true(grepl("^POLYGON", as.character(boundary)))
})

test_that("boundary has lonlat CRS", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  boundary <- a5_cell_to_boundary(cell)
  crs <- wk::wk_crs(boundary)
  expect_identical(crs, wk::wk_crs_longlat())
})

test_that("cell_area returns positive values", {
  areas <- a5_cell_area(0:5)
  expect_length(areas, 6L)
  expect_true(all(areas > 0))
  # areas should decrease with resolution

  expect_true(all(diff(areas) < 0))
})
