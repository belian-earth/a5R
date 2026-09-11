# One-to-many functions vectorised over cells: `simplify = TRUE` gives one
# flat vector, `simplify = FALSE` a list_of with one element per input.

cells <- a5_lonlat_to_cell(c(-3.19, 0, 139.7), c(55.95, 0, 35.69), resolution = 5)
ops <- list(
  children = function(x, ...) a5_cell_to_children(x, resolution = 7, ...),
  disk = function(x, ...) a5_grid_disk(x, k = 2, ...),
  cap = function(x, ...) a5_spherical_cap(x, radius = 200000, ...)
)

test_that("list form matches the scalar call element-wise", {
  for (op in ops) {
    lst <- op(cells, simplify = FALSE)
    expect_s3_class(lst, "a5_cell_list")
    expect_s3_class(lst, "vctrs_list_of")
    expect_length(lst, length(cells))
    for (i in seq_along(cells)) {
      expect_identical(lst[[i]], op(cells[i]))
    }
  }
})

test_that("flat form is the concatenation of the list form", {
  for (op in ops) {
    lst <- op(cells, simplify = FALSE)
    expect_identical(op(cells), vctrs::list_unchop(lst))
    expect_identical(op(cells[1]), lst[[1]])  # length-1 input unchanged
  }
})

test_that("NA input contributes nothing", {
  with_na <- c(cells[1], a5_cell(NA), cells[3])
  for (op in ops) {
    lst <- op(with_na, simplify = FALSE)
    expect_identical(lengths(lst)[2], 0L)
    expect_identical(lst[[1]], op(cells[1]))
    expect_identical(lst[[3]], op(cells[3]))
    expect_identical(op(with_na), vctrs::vec_c(op(cells[1]), op(cells[3])))
  }
})

test_that("a5_cell_list unlists to an a5_cell vector and survives slicing", {
  lst <- a5_cell_to_children(cells, resolution = 7, simplify = FALSE)
  expect_identical(unlist(lst), vctrs::list_unchop(lst))
  expect_identical(unlist(lst), a5_cell_to_children(cells, resolution = 7))
  expect_s3_class(unlist(lst), "a5_cell")
  expect_s3_class(lst[2:3], "a5_cell_list")
  expect_identical(unlist(lst[2:3]), a5_cell_to_children(cells[2:3], resolution = 7))
  expect_identical(vctrs::vec_ptype_abbr(lst), "list<a5_cell>")
  expect_length(unlist(a5_grid_disk(a5_cell(NA), k = 1, simplify = FALSE)), 0L)
})

test_that("a5_cell_list unnests with tidyr", {
  skip_if_not_installed("tidyr")
  skip_if_not_installed("tibble")
  df <- tibble::tibble(cell = cells)
  df$children <- a5_cell_to_children(df$cell, resolution = 6, simplify = FALSE)
  expect_match(format(vctrs::vec_ptype_abbr(df$children)), "list<a5_cell>")
  long <- tidyr::unnest(df, "children")
  expect_identical(nrow(long), 12L)
  expect_s3_class(long$children, "a5_cell")
  expect_identical(a5_cell_to_parent(long$children), long$cell)
  disks <- tidyr::unnest(
    tibble::tibble(cell = cells, disk = a5_grid_disk(cells, k = 1, simplify = FALSE)),
    "disk"
  )
  expect_identical(nrow(disks), length(a5_grid_disk(cells, k = 1)))
})

test_that("simplify must be a flag", {
  expect_error(a5_cell_to_children(cells, simplify = NA), "TRUE")
  expect_error(a5_grid_disk(cells, k = 1, simplify = "yes"), "TRUE")
  expect_error(a5_grid_disk(cells, k = 1, vertex = c(TRUE, FALSE)), "TRUE")
})

test_that("list form works as a tibble list column and unnests", {
  skip_if_not_installed("tibble")
  df <- tibble::tibble(cell = cells)
  df$children <- a5_cell_to_children(df$cell, resolution = 6, simplify = FALSE)
  expect_identical(lengths(df$children), rep(4L, 3))
  # Long form: parent repeated per child alongside the flat children.
  long <- vctrs::new_data_frame(list(
    parent = vctrs::vec_rep_each(df$cell, lengths(df$children)),
    child = vctrs::list_unchop(df$children)
  ))
  expect_identical(nrow(long), 12L)
  expect_identical(a5_cell_to_parent(long$child), long$parent)
})

test_that("threads give the same result", {
  skip_if(parallel::detectCores() < 2)
  withr::local_options(list())
  old <- a5_get_threads()
  on.exit(a5_set_threads(old))
  single <- a5_grid_disk(cells, k = 3, simplify = FALSE)
  a5_set_threads(2L)
  expect_identical(a5_grid_disk(cells, k = 3, simplify = FALSE), single)
})
