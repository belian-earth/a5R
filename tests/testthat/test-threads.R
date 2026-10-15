test_that("default threads is 1", {
    expect_equal(a5_get_threads(), 1L)
})

test_that("set/get threads works", {
    withr::defer(a5_set_threads(1L))
    old <- a5_set_threads(2L)
    expect_equal(old, 1L)
    expect_equal(a5_get_threads(), 2L)
})

test_that("results are identical with 1 vs 2 threads", {
    withr::defer(a5_set_threads(1L))
    cells <- a5_lonlat_to_cell(c(0, 10, -10), c(0, 20, -20), resolution = 5)

    a5_set_threads(1L)
    boundary_1 <- a5_cell_to_boundary(cells, format = "wkt")
    xy_1 <- a5_cell_to_boundary_xy(c(cells, NA))
    lonlat_1 <- a5_cell_to_lonlat(cells)
    parent_1 <- a5_cell_to_parent(cells)
    res_1 <- a5_get_resolution(cells)
    valid_1 <- a5_is_valid(cells)

    a5_set_threads(2L)
    boundary_2 <- a5_cell_to_boundary(cells, format = "wkt")
    xy_2 <- a5_cell_to_boundary_xy(c(cells, NA))
    lonlat_2 <- a5_cell_to_lonlat(cells)
    parent_2 <- a5_cell_to_parent(cells)
    res_2 <- a5_get_resolution(cells)
    valid_2 <- a5_is_valid(cells)

    expect_identical(as.character(boundary_1), as.character(boundary_2))
    expect_identical(xy_1, xy_2)
    expect_identical(lonlat_1, lonlat_2)
    expect_identical(as.character(parent_1), as.character(parent_2))
    expect_identical(res_1, res_2)
    expect_identical(valid_1, valid_2)
})

test_that("a5_set_threads rejects invalid counts and keeps the old one", {
  old <- a5_set_threads(1L)
  on.exit(a5_set_threads(old))
  expect_error(a5_set_threads(-1), "positive integer")
  expect_error(a5_set_threads(0), "positive integer")
  expect_error(a5_set_threads(NA), "positive integer")
  expect_identical(a5_get_threads(), 1L)
})

test_that("a Rust panic in a parallel call does not break later calls", {
  old <- a5_set_threads(2L)
  on.exit(a5_set_threads(old))
  # the world cell panicked inside the a5 crate (1.0.0-beta.3); whatever it
  # does now, later parallel calls and a5_set_threads() must still work
  try(a5_grid_disk(a5_cell("0000000000000000"), 1), silent = TRUE)
  cell <- a5_lonlat_to_cell(0, 0, 5)
  expect_length(a5_cell_to_children(cell, 7), 16L)
  expect_identical(a5_set_threads(1L), 2L)
  expect_length(a5_cell_to_children(cell, 7), 16L)
})

test_that("with_a5_threads and local_a5_threads restore the count", {
  old <- a5_set_threads(1L)
  on.exit(a5_set_threads(old))
  expect_identical(with_a5_threads(3, a5_get_threads()), 3L)
  expect_identical(a5_get_threads(), 1L)
  expect_error(with_a5_threads(2, stop("boom")), "boom")
  expect_identical(a5_get_threads(), 1L)
  f <- function() {
    local_a5_threads(4)
    a5_get_threads()
  }
  expect_identical(f(), 4L)
  expect_identical(a5_get_threads(), 1L)
})
