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
