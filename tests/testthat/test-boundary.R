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

test_that("boundary with closed = FALSE omits repeated vertex", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  open <- a5_cell_to_boundary(cell, closed = FALSE)
  closed <- a5_cell_to_boundary(cell, closed = TRUE)
  # closed ring repeats the first vertex, so its WKT is longer
  expect_true(nchar(as.character(closed)) > nchar(as.character(open)))
})

test_that("boundary with segments param works", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  b_default <- a5_cell_to_boundary(cell)
  b_seg <- a5_cell_to_boundary(cell, segments = 3L)
  # more segments = more vertices = longer WKT
  expect_true(nchar(as.character(b_seg)) > nchar(as.character(b_default)))
})

test_that("boundary is vectorised", {
  cells <- a5_lonlat_to_cell(c(0, 10, -10), c(0, 20, -20), resolution = 5)
  boundaries <- a5_cell_to_boundary(cells)
  expect_length(boundaries, 3L)
  expect_true(all(grepl("^POLYGON", as.character(boundaries))))
})

test_that("boundary handles NA cell", {
  cells <- a5_cell(c("0800000000000006", NA))
  boundaries <- a5_cell_to_boundary(cells)
  expect_length(boundaries, 2L)
  expect_true(is.na(as.character(boundaries)[2]))
})

test_that("cell_area decreases with
  resolution", {
  areas <- a5_cell_area(0:5)
  expect_true(all(diff(areas) < units::as_units(0, "m^2")))
})


test_that("cell_area converts units", {
  m2 <- a5_cell_area(5)
  km2 <- a5_cell_area(5, units = "km^2")
  expect_equal(as.numeric(m2) / 1e6, as.numeric(km2), tolerance = 1e-10)
})

test_that("cell_area rejects non-area units", {
  expect_error(a5_cell_area(5, units = "kg"), "area unit")
  expect_error(a5_cell_area(5, units = "nonsense"), "area unit")
})
