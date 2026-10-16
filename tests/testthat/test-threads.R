test_that("default threads is 1", {
    expect_equal(a5_get_threads(), 1L)
})

test_that("set/get threads works", {
    withr::defer(a5_set_threads(1L))
    old <- a5_set_threads(2L)
    expect_equal(as.integer(old), 1L)
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
  # the world cell panics inside the a5 crate (1.0.0); whatever it
  # does now, later parallel calls and a5_set_threads() must still work
  try(a5_grid_disk(a5_cell("0000000000000000"), 1), silent = TRUE)
  cell <- a5_lonlat_to_cell(0, 0, 5)
  expect_length(a5_cell_to_children(cell, 7), 16L)
  expect_identical(as.integer(a5_set_threads(1L)), 2L)
  expect_length(a5_cell_to_children(cell, 7), 16L)
})

test_that("with(a5_set_threads(n), expr) restores the count", {
  old <- a5_set_threads(1L)
  on.exit(a5_set_threads(old))
  expect_identical(with(a5_set_threads(3), a5_get_threads()), 3L)
  expect_identical(a5_get_threads(), 1L)
  expect_error(with(a5_set_threads(2), stop("boom")), "boom")
  expect_identical(a5_get_threads(), 1L)
  # nested blocks unwind in order
  with(a5_set_threads(2), {
    with(a5_set_threads(4), expect_identical(a5_get_threads(), 4L))
    expect_identical(a5_get_threads(), 2L)
  })
  expect_identical(a5_get_threads(), 1L)
  # the returned object prints and converts like the count
  prev <- a5_set_threads(2)
  expect_s3_class(prev, "a5_threads")
  expect_identical(as.integer(prev), 1L)
  expect_output(print(prev), "previous count: 1")
  a5_set_threads(prev)
  expect_identical(a5_get_threads(), 1L)
})

test_that("large inputs give identical results on 1 and 4 threads", {
  withr::defer(a5_set_threads(1L))
  set.seed(42)
  n <- 50000
  lon <- runif(n, -180, 180)
  lat <- runif(n, -85, 85)
  lon[c(7, 20000)] <- NA
  run <- function(threads) {
    a5_set_threads(threads)
    cells <- a5_lonlat_to_cell(lon, lat, 12)
    list(
      cells = cells,
      lonlat = a5_cell_to_lonlat(cells, as_dataframe = TRUE),
      parent = a5_cell_to_parent(cells, 8),
      super = a5_cell_to_supercell(cells, 8),
      kids = a5_uncompact(a5_cell_to_subcell(cells[1:2000], 14))
    )
  }
  expect_identical(run(1L), run(4L))
})
