test_that("cell_to_boundary returns wk_wkb by default", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
  boundary <- a5_cell_to_boundary(cell)
  expect_s3_class(boundary, "wk_wkb")
  expect_length(boundary, 1L)
})

test_that("boundary has lonlat CRS", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  boundary <- a5_cell_to_boundary(cell)
  crs <- wk::wk_crs(boundary)
  expect_identical(crs, wk::wk_crs_longlat())
})

test_that("boundary with closed = FALSE omits repeated vertex", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  open <- a5_cell_to_boundary(cell, format = "wkt", closed_ring = FALSE)
  closed <- a5_cell_to_boundary(cell, format = "wkt", closed_ring = TRUE)
  # closed ring repeats the first vertex, so its WKT is longer
  expect_true(nchar(as.character(closed)) > nchar(as.character(open)))
})

test_that("boundary with segments param works", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  b_default <- a5_cell_to_boundary(cell, format = "wkt")
  b_seg <- a5_cell_to_boundary(cell, format = "wkt", segments = 3L)
  # more segments = more vertices = longer WKT
  expect_true(nchar(as.character(b_seg)) > nchar(as.character(b_default)))
})

test_that("boundary format = wkt returns wk_wkt", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
  boundary <- a5_cell_to_boundary(cell, format = "wkt")
  expect_s3_class(boundary, "wk_wkt")
  expect_length(boundary, 1L)
  expect_true(grepl("^POLYGON", as.character(boundary)))
})

test_that("boundary format rejects invalid values", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  expect_error(a5_cell_to_boundary(cell, format = "geojson"), "format")
})

test_that("boundary is vectorised", {
  cells <- a5_lonlat_to_cell(c(0, 10, -10), c(0, 20, -20), resolution = 5)
  boundaries <- a5_cell_to_boundary(cells)
  expect_length(boundaries, 3L)
  expect_s3_class(boundaries, "wk_wkb")
})

test_that("boundary handles NA cell", {
  cells <- a5_cell(c("0800000000000006", NA))
  boundaries <- a5_cell_to_boundary(cells, format = "wkt")
  expect_length(boundaries, 2L)
  expect_true(is.na(as.character(boundaries)[2]))
})

test_that("cell_area decreases with resolution", {
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

test_that("boundary rejects invalid segments", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  expect_error(a5_cell_to_boundary(cell, segments = 0L), "positive integer")
  expect_error(a5_cell_to_boundary(cell, segments = -1L), "positive integer")
  expect_error(a5_cell_to_boundary(cell, segments = NA_integer_), "positive integer")
  expect_error(a5_cell_to_boundary_xy(cell, segments = 0L), "positive integer")
  expect_error(a5_cell_to_boundary_xy(cell, segments = 1:2), "size 1")
  expect_error(a5_cell_to_boundary_xy(cell, closed_ring = NA), "TRUE")
})

# Vertices of a5_cell_to_boundary() as x, y, lengths, for comparison.
boundary_coords <- function(cell, closed, segments = NULL) {
  wkb <- a5_cell_to_boundary(cell, closed_ring = closed, segments = segments)
  coords <- wk::wk_coords(wkb)
  lengths <- tabulate(coords$feature_id, nbins = length(cell))
  list(x = coords$x, y = coords$y, lengths = lengths)
}

test_that("boundary_xy returns flat x, y and lengths", {
  cells <- a5_lonlat_to_cell(c(0, 10, -10), c(0, 20, -20), resolution = 9)
  xy <- a5_cell_to_boundary_xy(cells)
  expect_named(xy, c("x", "y", "lengths"))
  expect_type(xy$x, "double")
  expect_type(xy$y, "double")
  expect_type(xy$lengths, "integer")
  expect_identical(xy$lengths, rep(5L, 3))
  expect_length(xy$x, 15L)
  expect_length(xy$y, 15L)
})

test_that("boundary_xy matches cell_to_boundary vertices", {
  lon <- c(-3.19, 120, -60, 45)
  lat <- c(55.95, -30, 10, 80)
  cells <- c(
    a5_lonlat_to_cell(lon, lat, resolution = 2),
    a5_lonlat_to_cell(lon, lat, resolution = 7),
    a5_lonlat_to_cell(lon, lat, resolution = 14)
  )
  expect_identical(
    a5_cell_to_boundary_xy(cells),
    boundary_coords(cells, closed = FALSE)
  )
  expect_identical(
    a5_cell_to_boundary_xy(cells, closed_ring = TRUE),
    boundary_coords(cells, closed = TRUE)
  )
  expect_identical(
    a5_cell_to_boundary_xy(cells, segments = 3L),
    boundary_coords(cells, closed = FALSE, segments = 3L)
  )
})

test_that("boundary_xy vertex counts follow resolution and segments", {
  cells <- a5_lonlat_to_cell(0, 0, resolution = c(3, 6, 10))
  # default segments: max(1, 2^(6 - resolution)) per edge, five edges
  expect_identical(a5_cell_to_boundary_xy(cells)$lengths, c(40L, 5L, 5L))
  expect_identical(
    a5_cell_to_boundary_xy(cells, closed_ring = TRUE, segments = 2L)$lengths,
    rep(11L, 3)
  )
})

test_that("boundary_xy gives NA cells length 0", {
  cells <- a5_cell(c(NA, "0800000000000006", NA))
  xy <- a5_cell_to_boundary_xy(cells)
  expect_identical(xy$lengths[c(1, 3)], c(0L, 0L))
  expect_length(xy$x, xy$lengths[2])

  empty <- a5_cell_to_boundary_xy(a5_cell(character()))
  expect_identical(empty, list(x = double(), y = double(), lengths = integer()))
})

test_that("boundary_xy keeps longitudes continuous across the antimeridian", {
  cell <- a5_lonlat_to_cell(179.99, 0, resolution = 5)
  xy <- a5_cell_to_boundary_xy(cell)
  expect_true(any(abs(xy$x) > 180))
  expect_lt(diff(range(xy$x)), 180)
})

test_that("the world cell's boundary is an empty polygon", {
  w <- a5_cell("0000000000000000")
  expect_identical(as.character(a5_cell_to_boundary(w, "wkt")), "POLYGON EMPTY")
  expect_identical(as.character(wk::as_wkt(a5_cell_to_boundary(w))), "POLYGON EMPTY")
  expect_identical(a5_cell_to_boundary_xy(w)$lengths, 0L)
})

test_that("the old closed argument still works but warns", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, 5)
  expect_warning(
    b <- a5_cell_to_boundary(cell, closed = FALSE),
    "renamed `closed_ring`", class = "a5R_warning_deprecated"
  )
  expect_identical(b, a5_cell_to_boundary(cell, closed_ring = FALSE))
  expect_warning(
    xy <- a5_cell_to_boundary_xy(cell, closed = TRUE),
    class = "a5R_warning_deprecated"
  )
  expect_identical(xy, a5_cell_to_boundary_xy(cell, closed_ring = TRUE))
})
