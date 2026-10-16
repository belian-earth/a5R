cell <- a5_lonlat_to_cell(0, 0, resolution = 8)

test_that("grid_disk k=0 is the centre cell alone", {
  result <- a5_grid_disk(cell, k = 0)
  expect_s3_class(result, "a5_covering")
  expect_length(result, 1L)
  expect_identical(a5_uncompact(result), cell)
})

test_that("grid_disk k=1 holds the centre and its neighbours", {
  result <- a5_uncompact(a5_grid_disk(cell, k = 1))
  expect_gt(length(result), 1L)
  expect_true(vctrs::vec_in(cell, result))
  expect_true(all(a5_get_resolution(result) == 8L))
})

test_that("grid_disk_vertex holds more cells than grid_disk", {
  edge <- a5_uncompact(a5_grid_disk(cell, k = 1))
  vert <- a5_uncompact(a5_grid_disk_vertex(cell, k = 1))
  expect_gt(length(vert), length(edge))
  expect_true(all(vctrs::vec_in(edge, vert)))
})

test_that("spherical_cap holds at least the centre cell", {
  result <- a5_uncompact(a5_spherical_cap(cell, radius = 1))
  expect_identical(result, cell)
})

test_that("spherical_cap with larger radius holds more cells", {
  small <- a5_uncompact(a5_spherical_cap(cell, radius = 100000))
  large <- a5_uncompact(a5_spherical_cap(cell, radius = 500000))
  expect_gt(length(large), length(small))
  expect_true(all(a5_get_resolution(large) == 8L))
})

test_that("traversal gives one covering per centre cell", {
  cells <- a5_lonlat_to_cell(c(-3.19, 0, 139.7), c(55.95, 0, 35.69), resolution = 5)
  disks <- a5_grid_disk(cells, k = 2)
  caps <- a5_spherical_cap(cells, radius = 200000)
  expect_length(disks, 3L)
  expect_length(caps, 3L)
  for (i in seq_along(cells)) {
    expect_identical(disks[i], a5_grid_disk(cells[i], k = 2))
    expect_identical(caps[i], a5_spherical_cap(cells[i], radius = 200000))
  }
  expect_identical(a5_covering_resolution(disks), rep(5L, 3))
  expect_true(all(a5_is_valid(c(disks, caps))))
})

test_that("grid_disk errors on invalid cell", {
  bad <- a5_cell("fd00000000000000")
  expect_error(a5_grid_disk(bad, k = 1), "Invalid cell")
  expect_error(a5_grid_disk_vertex(bad, k = 1), "Invalid cell")
})

test_that("grid_disk_vertex validates k and propagates NA", {
  expect_error(a5_grid_disk_vertex(cell, k = -1), class = "a5R_error_argument")
  expect_error(a5_grid_disk_vertex(cell, k = 1:2), "size 1")
  expect_error(a5_grid_disk_vertex(cell), "k")
  expect_identical(
    is.na(a5_grid_disk_vertex(c(cell, a5_cell(NA)), k = 1)),
    c(FALSE, TRUE)
  )
})

test_that("spherical_cap errors on invalid cell", {
  expect_error(a5_spherical_cap(a5_cell("fd00000000000000"), radius = 100), "Invalid cell")
})

test_that("traversal gives an NA covering for an NA cell", {
  x <- c(cell, a5_cell(NA))
  expect_identical(is.na(a5_grid_disk(x, k = 1)), c(FALSE, TRUE))
  expect_identical(is.na(a5_spherical_cap(x, radius = 100)), c(FALSE, TRUE))
  expect_identical(lengths(a5_uncompact(a5_grid_disk(x, k = 1), simplify = FALSE))[2], 0L)
})

test_that("k and radius are validated", {
  cell <- a5_lonlat_to_cell(0, 0, 5)
  expect_error(a5_grid_disk(cell, -1), "non-negative")
  expect_error(a5_grid_disk(cell, NA), "non-negative")
  for (r in c(-1, NaN, Inf, NA)) {
    expect_error(a5_spherical_cap(cell, r), "finite, non-negative")
  }
  expect_no_error(a5_spherical_cap(cell, 0))
})

test_that("a5_spherical_cap takes radius units", {
  cell <- a5_lonlat_to_cell(0, 0, 8)
  m <- a5_spherical_cap(cell, 5000)
  expect_identical(a5_spherical_cap(cell, 5, units = "km"), m)
  expect_identical(a5_spherical_cap(cell, units::set_units(5, "km")), m)
  expect_error(a5_spherical_cap(cell, 5, units = "kg"), "length unit")
})

test_that("the world cell is its own disk and cap", {
  world <- a5_cell("0000000000000000")
  cell <- a5_lonlat_to_cell(0, 0, 3)
  x <- c(world, cell, a5_cell(NA))
  expected <- as_a5_covering(world)
  for (res in list(a5_grid_disk(x, 2), a5_grid_disk_vertex(x, 2), a5_spherical_cap(x, 1e6))) {
    expect_identical(res[1], expected)
    expect_true(is.na(res[3]))
  }
  expect_identical(a5_grid_disk(x, 2)[2], a5_grid_disk(cell, 2))
})

