test_that("a5_is_valid_cell checks the index encoding", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
  hex <- c(
    format(cell),
    "0000000000000000", # world cell
    "fd00000000000000", # resolution 1 has no quintant 63
    "f00a000000000040", # compaction marker for resolution 10
    "0000000000000040", # tag bit 6: no resolution
    "not_a_cell_value",
    "12345678901234567", # 17 digits
    "200000000000000",  # unpadded, as the crate's u64_to_hex writes it
    "0x0200000000000000",
    NA
  )
  expected <- c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, NA)
  expect_identical(a5_is_valid_cell(hex), expected)
  # hex is read as a5_cell() reads it, so the same answer for a5_cell input
  parses <- -c(6, 7)
  expect_identical(a5_is_valid_cell(a5_cell(hex[parses])), expected[parses])
})

test_that("every cell the package produces is valid", {
  cells <- a5_lonlat_to_cell(c(-3.19, 0, 179.9, -60), c(55.95, 0, -89, 75), 0:3)
  expect_true(all(a5_is_valid_cell(cells)))
  fine <- a5_lonlat_to_cell(c(-3.19, 0, 179.9, -60), c(55.95, 0, -89, 75), 27)
  expect_true(all(a5_is_valid_cell(a5_cell_to_children(fine, 30))))
  expect_true(all(a5_is_valid_cell(a5_get_res0_cells())))
})

test_that("a5_is_valid dispatches on cells, hex and cell lists", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
  expect_identical(a5_is_valid(cell), TRUE)
  expect_identical(a5_is_valid(c(format(cell), "fd00000000000000")), c(TRUE, FALSE))

  lst <- as_a5_cell_list(list(
    a5_cell_to_children(cell),
    a5_cell(c(format(cell), "fd00000000000000")),
    a5_cell(c(format(cell), NA)),
    a5_cell(c("fd00000000000000", NA)),
    a5_cell()
  ))
  expect_identical(a5_is_valid(lst), c(TRUE, FALSE, NA, FALSE, TRUE))
})
