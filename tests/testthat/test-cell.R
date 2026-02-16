test_that("a5_cell constructor", {
  cell <- a5_cell("0800000000000006")
  expect_s3_class(cell, "a5_cell")
  expect_equal(vctrs::vec_data(cell), "0800000000000006")
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

test_that("a5_is_cell validates", {
  result <- a5_is_cell(c("0800000000000006", "not_valid", NA))
  expect_equal(result[1], TRUE)
  expect_equal(result[2], FALSE)
  expect_true(is.na(result[3]))
})
