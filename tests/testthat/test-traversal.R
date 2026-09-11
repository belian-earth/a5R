cell <- a5_lonlat_to_cell(0, 0, resolution = 8)

test_that("grid_disk k=0 returns only the centre cell", {
  result <- a5_grid_disk(cell, k = 0)
  expect_length(result, 1L)
  expect_equal(format(result), format(cell))
})

test_that("grid_disk k=1 returns centre + neighbours", {
  result <- a5_grid_disk(cell, k = 1)
  expect_true(length(result) > 1L)
})

test_that("grid_disk vertex=TRUE returns more cells than vertex=FALSE", {
  edge <- a5_grid_disk(cell, k = 1, vertex = FALSE)
  vert <- a5_grid_disk(cell, k = 1, vertex = TRUE)
  expect_true(length(vert) > length(edge))
})

test_that("spherical_cap returns at least the centre cell", {
  result <- a5_spherical_cap(cell, radius = 1)
  expect_true(length(result) >= 1L)
})

test_that("spherical_cap with larger radius returns more cells", {
  small <- a5_spherical_cap(cell, radius = 100000)
  large <- a5_spherical_cap(cell, radius = 500000)
  expect_true(length(large) > length(small))
})

test_that("grid_disk errors on invalid cell", {
  expect_error(a5_grid_disk(a5_cell("zzzz"), k = 1))
})

test_that("spherical_cap errors on invalid cell", {
  expect_error(a5_spherical_cap(a5_cell("zzzz"), radius = 100))
})

test_that("grid_disk gives no cells for an NA cell", {
  expect_length(a5_grid_disk(a5_cell(NA), k = 1), 0L)
  expect_identical(lengths(a5_grid_disk(a5_cell(NA), k = 1, simplify = FALSE)), 0L)
})

test_that("spherical_cap gives no cells for an NA cell", {
  expect_length(a5_spherical_cap(a5_cell(NA), radius = 100), 0L)
  expect_identical(lengths(a5_spherical_cap(a5_cell(NA), radius = 100, simplify = FALSE)), 0L)
})
