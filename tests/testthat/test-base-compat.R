set.seed(11)
n <- 5000L
x <- a5_lonlat_to_cell(runif(n, -180, 180), runif(n, -85, 85), resolution = 12)
y <- x[sample(n)]
a <- x[1:3]
b <- x[4:6]

test_that("match and %in% agree with vctrs, including NA", {
  expect_identical(match(x, y), vctrs::vec_match(x, y))
  expect_identical(x %in% y, vctrs::vec_in(x, y))
  xna <- c(a, a5_cell(NA), b)
  yna <- c(a5_cell(NA), b[2])
  expect_identical(match(xna, yna), vctrs::vec_match(xna, yna))
  expect_identical(match(a, b), rep(NA_integer_, 3))
  expect_identical(unique(c(a, a)), a)
})

test_that("mtfrm key is exact and distinct for distinct cells", {
  k <- mtfrm(x)
  expect_type(k, "complex")
  expect_identical(anyDuplicated(k) > 0, anyDuplicated(as.character(x)) > 0)
  expect_identical(vctrs::vec_unique_count(k), vctrs::vec_unique_count(x))
})

test_that("assignment past the end grows with NA", {
  z <- a
  z[5] <- b[1]
  expect_length(z, 5L)
  expect_true(is.na(z[4]))
  expect_identical(z[5], b[1])
  z <- a
  z[length(z) + 1] <- b[2]
  expect_identical(z, c(a, b[2]))
  # In-range assignment is still type checked by vctrs.
  expect_error(z[2] <- "not a cell")
  # Hex strings are still cast in range.
  z[2] <- as.character(b[3])
  expect_identical(z[2], b[3])
})

test_that("length<- grows with NA and shrinks", {
  z <- a
  length(z) <- 5
  expect_length(z, 5L)
  expect_true(all(is.na(z[4:5])))
  expect_identical(z[1:3], a)
  length(z) <- 2
  expect_identical(z, a[1:2])
})

test_that("rbind on data frames with a5_cell columns matches vec_rbind", {
  d1 <- data.frame(cell = a, v = 1:3)
  d2 <- data.frame(cell = b, v = 4:6)
  expect_identical(rbind(d1, d2), vctrs::vec_rbind(d1, d2))
  expect_identical(rbind(d1, d2)$cell, c(a, b))
})

test_that("as_a5_cell_list wraps plain lists so unlist works", {
  plain <- lapply(1:3, function(i) a5_cell_to_children(a[i]))
  expect_type(unlist(plain), "raw")  # the base behaviour being worked around
  lst <- as_a5_cell_list(plain)
  expect_s3_class(lst, "a5_cell_list")
  expect_identical(unlist(lst), a5_cell_to_children(a))
  expect_identical(as_a5_cell_list(lst), lst)
  mixed <- as_a5_cell_list(list(a, as.character(b), NULL))
  expect_identical(lengths(mixed), c(3L, 3L, 0L))
  expect_identical(unlist(mixed), c(a, b))
  expect_error(as_a5_cell_list(a), "list")
})

test_that("split of cells by a factor works; grouping by cells needs vctrs", {
  s <- split(a, c("p", "q", "p"))
  expect_identical(s$p, a[c(1, 3)])
  # split(x, cells) sees the record's fields, so use vec_split()
  g <- c(a[1], a[2], a[1])
  expect_identical(vctrs::vec_split(1:3, g)$val, list(c(1L, 3L), 2L))
})
