test_that("a5_covering_to_supercells matches supercells of the uncompacted cells", {
  polys <- wk::wkt(c(
    "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))",
    NA,
    "POLYGON ((10 0, 12 0, 12 2, 10 2, 10 0))"
  ))
  cv <- a5_polygon_to_cells(polys, 11)
  for (threads in c(1L, 2L)) {
    sc <- with(a5_set_threads(threads), a5_covering_to_supercells(cv, 7))
    expect_identical(is.na(sc), c(FALSE, TRUE, FALSE))
    for (i in c(1L, 3L)) {
      expect_identical(a5_covering_resolution(sc[i]), 7L)
      brute <- vctrs::vec_unique(a5_cell_to_supercell(a5_uncompact(cv[i]), 7))
      expect_setequal(format(a5_uncompact(sc[i])), format(brute))
    }
  }
  expect_identical(a5_covering_to_supercells(cv[1], 11), cv[1])
  expect_error(a5_covering_to_supercells(cv[1], 12), class = "a5R_error_resolution")
})

test_that("a5_covering_to_supercells is exact across resolutions and shapes", {
  brute <- function(cv, res) {
    format(vctrs::vec_sort(vctrs::vec_unique(a5_cell_to_supercell(a5_uncompact(cv), res))))
  }
  fast <- function(cv, res) format(vctrs::vec_sort(a5_uncompact(a5_covering_to_supercells(cv, res))))
  shapes <- wk::wkt(c(
    # two separate parts, so the search needs a seed in each
    "MULTIPOLYGON (((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9)), ((2.2 48.8, 2.5 48.8, 2.5 48.9, 2.2 48.9, 2.2 48.8)))",
    # across the antimeridian
    "POLYGON ((179.5 -17, -179.5 -17, -179.5 -16, 179.5 -16, 179.5 -17))",
    # a thin sliver
    "POLYGON ((10 0, 10.6 0, 10.6 0.004, 10 0.004, 10 0))",
    # near a pole
    "POLYGON ((0 85, 60 85, 120 85, 180 85, -120 85, -60 85, 0 85))"
  ))
  for (i in seq_along(shapes)) {
    for (rr in list(c(11, 7), c(11, 10), c(9, 1), c(9, 0), c(12, 4))) {
      cv <- a5_polygon_to_cells(shapes[i], rr[1], containment = "overlapping")
      expect_identical(fast(cv, rr[2]), brute(cv, rr[2]), info = paste(i, rr[1], rr[2]))
    }
  }
  # a disk covering, and the same with threads
  disk <- a5_grid_disk(a5_lonlat_to_cell(30, 30, 10), k = 20)
  expect_identical(fast(disk, 6), brute(disk, 6))
  expect_identical(with(a5_set_threads(3), fast(disk, 6)), brute(disk, 6))
})
