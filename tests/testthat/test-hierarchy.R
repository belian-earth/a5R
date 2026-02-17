test_that("get_resolution extracts resolution", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 10)
  expect_equal(a5_get_resolution(cell), 10L)
})

test_that("cell_to_parent returns coarser cell", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 10)
  parent <- a5_cell_to_parent(cell)
  expect_equal(a5_get_resolution(parent), 9L)
})

test_that("cell_to_parent with explicit resolution", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 10)
  parent <- a5_cell_to_parent(cell, resolution = 5)
  expect_equal(a5_get_resolution(parent), 5L)
})

test_that("cell_to_children returns 4 children", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  children <- a5_cell_to_children(cell)
  expect_length(children, 4L)
  expect_true(all(a5_get_resolution(children) == 6L))
})

test_that("get_resolution is vectorised", {
  cells <- a5_lonlat_to_cell(c(0, 10), c(0, 10), resolution = c(3L, 7L))
  expect_equal(a5_get_resolution(cells), c(3L, 7L))
})

test_that("cell_to_parent is vectorised", {
  cells <- a5_lonlat_to_cell(c(0, 10), c(0, 10), resolution = 10)
  parents <- a5_cell_to_parent(cells)
  expect_length(parents, 2L)
  expect_true(all(a5_get_resolution(parents) == 9L))
})

test_that("cell_to_children with explicit resolution", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  children <- a5_cell_to_children(cell, resolution = 7)
  expect_length(children, 16L)
  expect_true(all(a5_get_resolution(children) == 7L))
})

test_that("res0 cells", {
  cells <- a5_get_res0_cells()
  expect_length(cells, 12L)
  expect_true(all(a5_get_resolution(cells) == 0L))
})

test_that("get_num_cells returns positive double", {
  n <- a5_get_num_cells(0)
  expect_type(n, "double")
  expect_equal(n, 12)
})

test_that("get_num_cells increases with resolution", {
  n5 <- a5_get_num_cells(5)
  n10 <- a5_get_num_cells(10)
  expect_true(n10 > n5)
})
