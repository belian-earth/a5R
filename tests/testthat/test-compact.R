test_that("compact reverses children", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  children <- a5_cell_to_children(cell)
  compacted <- a5_compact(children)
  expect_equal(vctrs::vec_data(compacted), vctrs::vec_data(cell))
})

test_that("compact with partial siblings is a no-op", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  children <- a5_cell_to_children(cell)
  partial <- children[1:2]
  compacted <- a5_compact(partial)
  expect_length(compacted, 2L)
})

test_that("compact with single cell is a no-op", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  compacted <- a5_compact(cell)
  expect_equal(vctrs::vec_data(compacted), vctrs::vec_data(cell))
})

test_that("uncompact expands to target resolution", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  expanded <- a5_uncompact(cell, resolution = 7)
  expect_length(expanded, 16L) # 4^2 = 16
  expect_true(all(a5_get_resolution(expanded) == 7L))
})

test_that("compact and uncompact round-trip", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  expanded <- a5_uncompact(cell, resolution = 7)
  compacted <- a5_compact(expanded)
  expect_equal(vctrs::vec_data(compacted), vctrs::vec_data(cell))
})
