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
