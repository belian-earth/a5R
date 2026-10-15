test_that("index and crate versions", {
  expect_identical(a5_index_version(), "1.0")
  v <- a5_crate_version()
  expect_type(v, "character")
  expect_match(v, "^1\\.0\\.0")
})
