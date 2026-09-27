# Reference definition: the coarse cell containing the fine cell's centre,
# via a lon/lat round trip through exported functions.
centre_cell <- function(cell, resolution) {
  ll <- unclass(a5_cell_to_lonlat(cell))
  a5_lonlat_to_cell(ll$x, ll$y, resolution)
}

random_cells <- function(n, resolution, seed) {
  withr::with_seed(seed, {
    lon <- stats::runif(n, -180, 180)
    lat <- asin(stats::runif(n, -1, 1)) * 180 / pi
  })
  a5_lonlat_to_cell(lon, lat, resolution)
}

test_that("spatial_parent matches the lon/lat round trip", {
  for (res in c(2, 9, 18, 25)) {
    fine <- random_cells(500, res + 3, seed = res)
    for (gap in 1:3) {
      expect_identical(
        a5_cell_to_spatial_parent(fine, res + 3 - gap),
        centre_cell(fine, res + 3 - gap)
      )
    }
  }
})

test_that("spatial_parent differs from the index parent for many cells", {
  fine <- random_cells(1000, 18, seed = 1)
  differ <- mean(a5_cell_to_spatial_parent(fine, 14) != a5_cell_to_parent(fine, 14))
  expect_gt(differ, 0.2)
})

test_that("spatial_children is complete and the exact inverse of spatial_parent", {
  for (res in c(0, 1, 2, 7, 16)) {
    coarse <- unique(random_cells(20, res, seed = 10 + res))
    for (gap in c(1, 3)) {
      fine_res <- res + gap
      for (i in seq_along(coarse)) {
        kids <- a5_cell_to_spatial_children(coarse[i], fine_res)
        # every returned cell has this spatial parent
        expect_true(all(a5_cell_to_spatial_parent(kids, res) == coarse[i]))
        # nothing is missing from a wide search area (k = 2 around the cell)
        area <- a5_cell_to_children(a5_grid_disk(coarse[i], 2, vertex = TRUE), fine_res)
        expected <- area[centre_cell(area, res) == coarse[i]]
        expect_identical(kids, vctrs::vec_sort(expected))
      }
    }
  }
})

test_that("spatial_children is exact at large gaps, fine resolutions and the poles", {
  check <- function(coarse, fine_res) {
    res <- a5_get_resolution(coarse[1])
    for (i in seq_along(coarse)) {
      kids <- a5_cell_to_spatial_children(coarse[i], fine_res)
      area <- a5_cell_to_children(a5_grid_disk(coarse[i], 2, vertex = TRUE), fine_res)
      expect_identical(kids, vctrs::vec_sort(area[centre_cell(area, res) == coarse[i]]))
    }
  }
  check(unique(random_cells(8, 6, seed = 40)), 12)
  check(unique(random_cells(8, 24, seed = 41)), 28)
  check(unique(random_cells(4, 26, seed = 42)), 30)
  # one cell per face, including faces that cannot be encoded at resolution 30
  faces <- a5_uncompact(a5_get_res0_cells(), 0)
  face_cells <- a5_lonlat_to_cell(
    unclass(a5_cell_to_lonlat(faces))$x, unclass(a5_cell_to_lonlat(faces))$y, 28
  )
  check(face_cells, 30)
  poles <- a5_lonlat_to_cell(c(0, 90, -45, 170), c(90, 89.99, -90, -89.99), 9)
  check(unique(poles), 13)
})

test_that("spatial children of a patch partition the patch's fine cells", {
  centre <- a5_lonlat_to_cell(-53.5, -19, resolution = 12)
  patch <- a5_uncompact(a5_grid_disk(centre, 2, vertex = TRUE), 12)
  kids <- a5_cell_to_spatial_children(patch, resolution = 14)
  expect_false(anyDuplicated(kids) > 0)
  # every fine cell whose centre falls in the patch is covered exactly once
  area <- a5_cell_to_children(a5_grid_disk(centre, 3, vertex = TRUE), 14)
  inside <- area[vctrs::vec_in(centre_cell(area, 12), patch)]
  expect_identical(vctrs::vec_sort(kids), vctrs::vec_sort(inside))
})

test_that("spatial children counts average 4^d", {
  coarse <- random_cells(200, 10, seed = 3)
  kids <- a5_cell_to_spatial_children(coarse, resolution = 13, simplify = FALSE)
  expect_equal(mean(lengths(kids)), 64, tolerance = 0.05)
  res0 <- a5_get_res0_cells()
  expect_length(a5_cell_to_spatial_children(res0), 60)
})

test_that("spatial functions default to one resolution step", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
  expect_identical(a5_cell_to_spatial_parent(cell), a5_cell_to_spatial_parent(cell, 9))
  expect_identical(a5_cell_to_spatial_children(cell), a5_cell_to_spatial_children(cell, 11))
})

test_that("spatial functions handle equal, invalid and NA resolutions", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
  expect_identical(a5_cell_to_spatial_parent(cell, 10), cell)
  expect_identical(a5_cell_to_spatial_children(cell, 10), cell)
  expect_true(is.na(a5_cell_to_spatial_parent(cell, 12)))
  expect_true(is.na(a5_cell_to_spatial_parent(a5_get_res0_cells()[1])))
  expect_error(a5_cell_to_spatial_children(cell, 8), "coarser")

  x <- a5_cell(c(format(cell), NA))
  expect_true(is.na(a5_cell_to_spatial_parent(x, 5)[2]))
  expect_length(a5_cell_to_spatial_children(x, 11), length(a5_cell_to_spatial_children(cell, 11)))
  lst <- a5_cell_to_spatial_children(x, 11, simplify = FALSE)
  expect_s3_class(lst, "a5_cell_list")
  expect_identical(lengths(lst)[2], 0L)
})

test_that("the world cell's spatial children are all cells", {
  world <- a5_cell("0000000000000000")
  expect_identical(a5_cell_to_spatial_children(world, 0), a5_cell_to_children(world, 0))
})
