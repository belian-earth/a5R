test_that("cell_child matches cell_to_children element-wise", {
  for (r in c(0L, 1L, 2L, 5L)) {
    cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = r)
    for (rc in c(r, r + 1L, r + 3L)) {
      children <- a5_cell_to_children(cell, resolution = rc)
      n <- length(children)
      expect_identical(a5_cell_child(cell, rc, seq_len(n)), children)
    }
  }
  world <- a5_cell_to_parent(a5_get_res0_cells()[1])
  expect_identical(a5_cell_child(world, 1L, 1:60), a5_cell_to_children(world, 1L))
})

test_that("cell_child recycles, handles NA and rejects out of range", {
  cells <- a5_lonlat_to_cell(c(0, 10, 20), c(0, 10, 20), resolution = 5)
  expect_identical(
    a5_cell_child(cells, 6L, 2L),
    vctrs::vec_c(
      a5_cell_to_children(cells[1])[2],
      a5_cell_to_children(cells[2])[2],
      a5_cell_to_children(cells[3])[2]
    )
  )
  res <- a5_cell_child(c(cells[1], a5_cell(NA)), 6L, c(1L, 1L))
  expect_false(is.na(res[1]))
  expect_true(is.na(res[2]))
  expect_true(is.na(a5_cell_child(cells[1], 6L, NA)))
  expect_error(a5_cell_child(cells[1], 6L, 5L), "out of range")
  expect_error(a5_cell_child(cells[1], 6L, 0L), "out of range")
  expect_error(a5_cell_child(cells[1], 4L, 1L), "resolution")
})

test_that("children_range brackets exactly the descendants", {
  set.seed(7)
  others <- a5_lonlat_to_cell(runif(3000, -180, 180), runif(3000, -85, 85), 8L)
  for (r in c(0L, 1L, 2L, 5L)) {
    cells <- a5_lonlat_to_cell(runif(5, -180, 180), runif(5, -85, 85), r)
    rng <- a5_cell_children_range(cells, 8L)
    expect_s3_class(rng, "data.frame")
    expect_named(rng, c("lo", "hi"))
    for (j in seq_along(cells)) {
      children <- vctrs::vec_sort(a5_cell_to_children(cells[j], 8L))
      expect_identical(rng$lo[j], children[1])
      expect_identical(rng$hi[j], children[length(children)])
      inside <- others[others >= rng$lo[j] & others <= rng$hi[j]]
      expect_true(all(a5_cell_to_parent(inside, r) == cells[j]))
    }
  }
  # Same resolution: the range collapses to the cell itself.
  cell <- a5_lonlat_to_cell(0, 0, 5L)
  rng <- a5_cell_children_range(cell, 5L)
  expect_identical(rng$lo, cell)
  expect_identical(rng$hi, cell)
  rng <- a5_cell_children_range(c(cell, a5_cell(NA)), 6L)
  expect_true(is.na(rng$lo[2]) && is.na(rng$hi[2]))
  expect_error(a5_cell_children_range(cell, 4L), "resolution")
})

test_that("children_range refuses resolution 30", {
  cell <- a5_lonlat_to_cell(0, 0, 20L)
  expect_error(a5_cell_children_range(cell, 30L), "not contiguous at resolution 30")
  expect_error(a5_cell_children_range(cell, 30), "29 or less")
  # 29 remains fine, including for a resolution-29 cell itself.
  c29 <- a5_lonlat_to_cell(0, 0, 29L)
  expect_identical(a5_cell_children_range(c29, 29L)$lo, c29)
})
