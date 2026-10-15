test_that("a5_cell_to_resolution moves cells by location", {
  cells <- a5_lonlat_to_cell(c(-3.19, -3.20, -3.19), c(55.95, 55.96, 55.95), 12)
  up <- a5_cell_to_resolution(c(cells, NA), 9)
  expect_identical(up, vctrs::vec_unique(a5_cell_to_supercell(cells, 9)))
  down <- a5_cell_to_resolution(cells, 14)
  expect_identical(a5_get_resolution(down), rep(14L, length(down)))
  # the finer cells map back to exactly the input cells
  expect_setequal(format(a5_cell_to_supercell(down, 12)), format(unique(cells)))
  expect_identical(a5_cell_to_resolution(cells, 12), vctrs::vec_unique(cells))
  expect_length(a5_cell_to_resolution(a5_cell(character()), 5), 0L)
  mixed <- c(cells[1], a5_cell_to_parent(cells[2]))
  expect_error(a5_cell_to_resolution(mixed, 5), class = "a5R_error_resolution")
})

test_that("a5_covering_to_supercells matches supercells of the uncompacted cells", {
  polys <- wk::wkt(c(
    "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))",
    NA,
    "POLYGON ((10 0, 12 0, 12 2, 10 2, 10 0))"
  ))
  cv <- a5_polygon_to_cells(polys, 11)
  for (threads in c(1L, 2L)) {
    sc <- with_a5_threads(threads, a5_covering_to_supercells(cv, 7))
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
