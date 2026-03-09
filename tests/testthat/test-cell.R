test_that("a5_cell constructor", {
  cell <- a5_cell("0800000000000006")
  expect_s3_class(cell, "a5_cell")
  expect_s3_class(cell, "vctrs_rcrd")
  expect_true(is.double(vctrs::field(cell, "hi")))
  expect_true(is.double(vctrs::field(cell, "lo")))
})

test_that("a5_cell coercion with character", {
  cell <- a5_cell("0800000000000006")
  combined <- vctrs::vec_c(cell, "0800000000000016")
  expect_s3_class(combined, "a5_cell")
  expect_length(combined, 2L)
})

test_that("is_a5_cell works", {
  expect_true(is_a5_cell(a5_cell("abc")))
  expect_false(is_a5_cell("abc"))
})

test_that("a5_is_valid validates", {
  result <- a5_is_valid(c("0800000000000006", "not_valid", NA))
  expect_equal(result[1], TRUE)
  expect_equal(result[2], FALSE)
  expect_true(is.na(result[3]))
})

test_that("a5_is_valid works with a5_cell input", {
  cell <- a5_cell("0800000000000006")
  expect_true(a5_is_valid(cell))
})

test_that("as_a5_cell passes through a5_cell unchanged", {
  cell <- a5_cell("0800000000000006")
  expect_identical(as_a5_cell(cell), cell)
})

test_that("as_a5_cell coerces character", {
  cell <- as_a5_cell("0800000000000006")
  expect_s3_class(cell, "a5_cell")
})

test_that("a5_cell handles NA values", {
  cell <- a5_cell(c("0800000000000006", NA))
  expect_length(cell, 2L)
  # NA is represented as NA_real_ in hi/lo fields
  expect_true(is.na(vctrs::field(cell, "hi")[2]))
  expect_true(is.na(vctrs::field(cell, "lo")[2]))
})

test_that("format.a5_cell preserves hex strings", {
  cell <- a5_cell(c("0800000000000006", NA))
  formatted <- format(cell)
  expect_equal(formatted[1], "0800000000000006")
  expect_true(is.na(formatted[2]))
})

test_that("a5_u64_to_hex works", {
  cell <- a5_cell("0800000000000006")
  expect_equal(a5_u64_to_hex(cell), "0800000000000006")
})

test_that("a5_hex_to_u64 works", {
  cell <- a5_hex_to_u64("0800000000000006")
  expect_s3_class(cell, "a5_cell")
  expect_equal(format(cell), "0800000000000006")
})

test_that("vec_cast round-trips a5_cell <-> character", {
  cell <- a5_cell("0800000000000006")
  chr <- vctrs::vec_cast(cell, character())
  expect_equal(chr, "0800000000000006")
  back <- vctrs::vec_cast(chr, a5_cell())
  expect_s3_class(back, "a5_cell")
  expect_equal(format(back), "0800000000000006")
})

test_that("vec_c combines a5_cell + a5_cell", {
  a <- a5_cell("0800000000000006")
  b <- a5_cell("0800000000000016")
  combined <- vctrs::vec_c(a, b)
  expect_s3_class(combined, "a5_cell")
  expect_length(combined, 2L)
  expect_equal(
    format(combined),
    c("0800000000000006", "0800000000000016")
  )
})

test_that("vec_c combines character + a5_cell (character first)", {
  cell <- a5_cell("0800000000000016")
  combined <- vctrs::vec_c("0800000000000006", cell)
  expect_s3_class(combined, "a5_cell")
  expect_length(combined, 2L)
})

test_that("vec_ptype_abbr and vec_ptype_full dispatch correctly", {
  cell <- a5_cell("0800000000000006")
  expect_equal(vec_ptype_abbr.a5_cell(cell), "a5_cell")
  expect_equal(vec_ptype_full.a5_cell(cell), "a5_cell")
})

test_that("pillar_shaft.a5_cell formats correctly", {
  skip_if_not_installed("pillar")
  cell <- a5_cell(c("0800000000000006", NA))
  shaft <- pillar_shaft.a5_cell(cell)
  expect_s3_class(shaft, "pillar_shaft")
})

test_that("a5_cell displays correctly in tibbles", {
  skip_if_not_installed("tibble")
  skip_if_not_installed("pillar")
  tbl <- tibble::tibble(
    cell = a5_cell(c("0800000000000006", "0800000000000016"))
  )

  testthat::expect_snapshot(tbl)

  out <- format(tbl)
  expect_true(any(grepl("a5_cell", out)))
  expect_true(any(grepl("0800000000000006", out)))
})

test_that("str works on a5_cell", {
  cell <- a5_cell(c("0800000000000006", "0800000000000016"))
  out <- capture.output(str(cell))
  expect_true(any(grepl("a5_cell", out)))
})

test_that("wk_crs.a5_cell returns longlat CRS", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  expect_identical(wk::wk_crs(cell), wk::wk_crs_longlat())
})

test_that("wk_handle.a5_cell produces boundary geometry", {
  cell <- a5_lonlat_to_cell(0, 0, resolution = 5)
  wkt <- wk::wk_handle(cell, wk::wkt_writer())
  expect_s3_class(wkt, "wk_wkt")
  expect_true(grepl("^POLYGON", as.character(wkt)))
})

test_that("a5_cell memory is contiguous (not list-of-raw)", {
  cells <- a5_lonlat_to_cell(runif(1000, -180, 180), runif(1000, -80, 80), 10L)
  # Should be ~16 KB (2 x 8 bytes x 1000), not ~56 KB+ from list-of-raw
  sz <- as.numeric(object.size(cells))
  expect_true(sz < 50000)  # well under list-of-raw overhead
})
