cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
children <- a5_cell_to_children(cell)

test_that("compact stores complete siblings as their parent", {
  covering <- a5_compact(children)
  expect_s3_class(covering, "a5_covering")
  expect_length(covering, 1L)
  expect_identical(a5_covering_resolution(covering), 6L)
  expect_identical(covering, a5_compact(cell, resolution = 6))
})

test_that("compact with partial siblings keeps them", {
  covering <- a5_compact(children[1:2])
  expect_identical(a5_uncompact(covering), vctrs::vec_sort(children[1:2]))
})

test_that("compact of a single cell stands for that cell", {
  covering <- a5_compact(cell)
  expect_identical(a5_covering_resolution(covering), 5L)
  expect_identical(a5_uncompact(covering), cell)
})

test_that("uncompact expands to the covering's resolution or finer", {
  expanded <- a5_uncompact(a5_compact(cell), resolution = 7)
  expect_length(expanded, 16L)
  expect_true(all(a5_get_resolution(expanded) == 7L))
  expect_identical(expanded, a5_cell_to_children(cell, resolution = 7))
  expect_error(a5_uncompact(a5_compact(children), resolution = 5), "coarser")
})

test_that("uncompact accepts plain cells as one covering", {
  # the resolution defaults to the finest cell's
  mixed <- c(cell, a5_cell_to_children(a5_lonlat_to_cell(10, 10, 5)))
  out <- a5_uncompact(mixed)
  expect_true(all(a5_get_resolution(out) == 6L))
  expect_length(out, 8L)
  expect_length(a5_uncompact(cell, resolution = 7), 16L)
})

test_that("compact and uncompact round-trip, sorted and deduplicated", {
  kids <- a5_cell_to_children(cell, resolution = 8)
  shuffled <- c(kids[c(40, 3, 64)], kids, kids[1:5])
  expect_identical(a5_uncompact(a5_compact(shuffled)), vctrs::vec_sort(kids))
  expect_identical(a5_compact(shuffled), a5_compact(cell, resolution = 8))
})

test_that("compact skips NA cells", {
  with_na <- vctrs::vec_c(children, a5_cell(NA))
  expect_identical(a5_compact(with_na), a5_compact(children))
})

test_that("compact refuses a resolution coarser than its cells", {
  expect_error(a5_compact(children, resolution = 5), "finer than resolution 5")
})

test_that("compact of no cells is empty", {
  covering <- a5_compact(a5_cell())
  expect_length(covering, 1L)
  expect_length(a5_uncompact(covering), 0L)
  expect_identical(a5_uncompact(a5_compact(a5_cell(), resolution = 4)), a5_cell())
  expect_identical(a5_covering_resolution(a5_compact(a5_cell(), resolution = 4)), 4L)
})

test_that("uncompact refuses to build too many cells", {
  world <- a5_compact(a5_get_res0_cells())
  expect_error(a5_uncompact(world, resolution = 20), "Uncompacting would build")
})
