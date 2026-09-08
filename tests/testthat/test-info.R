# -- a5_get_num_children ------------------------------------------------------

test_that("get_num_children returns correct count for aperture 4", {
  # Each resolution step is aperture 4, so 3 steps = 4^3 = 64
  expect_equal(a5_get_num_children(5, 8), 64)
})

test_that("get_num_children same resolution returns 1", {
  expect_equal(a5_get_num_children(5, 5), 1)
})

test_that("get_num_children child < parent returns 0", {
  expect_equal(a5_get_num_children(8, 5), 0)
})

test_that("get_num_children from resolution 0", {
  # res 0 has 12 cells, res 1 has 60 cells -> 5 children per res-0 cell
  expect_equal(a5_get_num_children(0, 1), 5)
})

test_that("get_num_children is consistent with get_num_cells", {
  # num_cells(child) / num_cells(parent) should equal num_children
  parent <- 3L
  child <- 7L
  ratio <- a5_get_num_cells(child) / a5_get_num_cells(parent)
  expect_equal(a5_get_num_children(parent, child), ratio)
})

# -- a5_cell_area --------------------------------------------------------------

test_that("cell_area with units = NULL returns plain numeric in m^2", {
  a_null <- a5_cell_area(5, units = NULL)
  a_m2 <- a5_cell_area(5, units = "m^2")
  expect_type(a_null, "double")
  expect_false(inherits(a_null, "units"))
  expect_equal(a_null, as.numeric(a_m2))
})

test_that("get_num_children validates resolution", {
  expect_error(a5_get_num_children(-1, 5), "resolution")
  expect_error(a5_get_num_children(5, 31), "resolution")
})

# -- a5_cell_edge_length_avg ---------------------------------------------------

test_that("cell_edge_length_avg returns a units vector in metres by default", {
  e <- a5_cell_edge_length_avg(0:5)
  expect_s3_class(e, "units")
  expect_equal(as.character(units(e)), "m")
  expect_length(e, 6L)
  expect_true(all(as.numeric(e) > 0))
})

test_that("cell_edge_length_avg decreases with resolution beyond res 1", {
  e <- as.numeric(a5_cell_edge_length_avg(1:30))
  expect_true(all(diff(e) < 0))
})

test_that("cell_edge_length_avg scales with sqrt(cell_area)", {
  # Upstream defines edge length as ratio * sqrt(area); at fine resolutions
  # the ratio is constant (0.8211), so the two halve together per level.
  e <- as.numeric(a5_cell_edge_length_avg(10:15))
  a <- as.numeric(a5_cell_area(10:15, units = NULL))
  expect_equal(e / sqrt(a), rep(0.8211, 6L), tolerance = 1e-6)
})

test_that("cell_edge_length_avg converts units", {
  e_m <- a5_cell_edge_length_avg(10)
  e_km <- a5_cell_edge_length_avg(10, units = "km")
  expect_equal(as.character(units(e_km)), "km")
  expect_equal(as.numeric(e_km) * 1000, as.numeric(e_m))
})

test_that("cell_edge_length_avg with units = NULL returns plain numeric", {
  e_null <- a5_cell_edge_length_avg(5, units = NULL)
  expect_type(e_null, "double")
  expect_false(inherits(e_null, "units"))
  expect_equal(e_null, as.numeric(a5_cell_edge_length_avg(5)))
})

test_that("cell_edge_length_avg propagates NA", {
  e <- a5_cell_edge_length_avg(c(3L, NA), units = NULL)
  expect_true(is.na(e[2]))
  expect_false(is.na(e[1]))
})

test_that("cell_edge_length_avg validates inputs", {
  expect_error(a5_cell_edge_length_avg(-1), "resolution")
  expect_error(a5_cell_edge_length_avg(31), "resolution")
  expect_error(a5_cell_edge_length_avg(5, units = "km^2"), "length unit")
})
