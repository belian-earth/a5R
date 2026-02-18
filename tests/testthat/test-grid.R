# -- input validation -----------------------------------------------------------

test_that("a5_grid rejects bad bbox", {
  expect_error(a5_grid(c(1, 2, 3), resolution = 3), "length 4")
  expect_error(a5_grid(c(1, 2, NA, 4), resolution = 3), "NA")
  expect_error(a5_grid(c(0, 10, 1, 5), resolution = 3), "ymin")
  expect_error(a5_grid(c(0, 5, 1, 5), resolution = 3), "ymin")
  expect_error(a5_grid(c(5, 0, 5, 1), resolution = 3), "xmin.*xmax.*equal")
})

test_that("a5_grid rejects invalid resolution", {
  expect_error(a5_grid(c(0, 0, 1, 1), resolution = -1))
  expect_error(a5_grid(c(0, 0, 1, 1), resolution = 31))
})

# -- return type ---------------------------------------------------------------

test_that("a5_grid returns a5_cell at correct resolution", {
  cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) > 0)
  expect_true(all(a5_get_resolution(cells) == 5L))
})

# -- correctness ---------------------------------------------------------------

test_that("res 0 with global bbox returns 12 cells", {
  cells <- a5_grid(c(-180, -90, 180, 90), resolution = 0)
  expect_length(cells, 12L)
})

test_that("result cells intersect the target (bbox path)", {
  bbox <- c(-3.3, 55.9, -3.1, 56.0)
  cells <- a5_grid(bbox, resolution = 5)
  target_wkt <- sprintf(
    "POLYGON ((%s %s, %s %s, %s %s, %s %s, %s %s))",
    bbox[1], bbox[2], bbox[3], bbox[2], bbox[3], bbox[4],
    bbox[1], bbox[4], bbox[1], bbox[2]
  )
  filtered <- a5_grid_intersects_rs(vctrs::vec_data(cells), target_wkt)
  expect_equal(length(filtered), length(cells))
})

test_that("geometry input filters cells by intersection", {
  # Triangle is strictly smaller than its bounding box, so the exact

  # intersection filter should return fewer cells than a bbox grid
  tri <- wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.95, -3.3 56, -3.3 55.9))")
  tri_cells <- a5_grid(tri, resolution = 8)
  bbox_cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 8)
  expect_true(length(tri_cells) < length(bbox_cells))
  # All triangle cells should be a subset of the bbox cells
  expect_true(all(vctrs::vec_data(tri_cells) %in% vctrs::vec_data(bbox_cells)))
})

test_that("interior point is covered by a returned cell", {
  bbox <- c(-3.3, 55.9, -3.1, 56.0)
  cells <- a5_grid(bbox, resolution = 5)
  # the centroid of the bbox should fall inside one of the cells
  centre <- a5_lonlat_to_cell(-3.2, 55.95, resolution = 5)
  expect_true(any(vctrs::vec_data(cells) == vctrs::vec_data(centre)))
})

test_that("no duplicate cells", {
  cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 5)
  expect_equal(length(cells), length(unique(vctrs::vec_data(cells))))
})

# -- input types ---------------------------------------------------------------

test_that("a5_grid accepts wkt polygon", {
  poly <- wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))")
  cells <- a5_grid(poly, resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) > 0)
})

test_that("a5_grid accepts a5_cell as area", {
  cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 3)
  children <- a5_grid(cell, resolution = 5)
  expect_s3_class(children, "a5_cell")
  expect_true(length(children) > 0)
  expect_true(all(a5_get_resolution(children) == 5L))
})

# -- edge cases ----------------------------------------------------------------

test_that("res 1 works (below filter threshold)", {
  cells <- a5_grid(c(-180, -90, 180, 90), resolution = 1)
  expect_s3_class(cells, "a5_cell")
  expect_true(all(a5_get_resolution(cells) == 1L))
})

test_that("tiny bbox returns at least 1 cell", {
  cells <- a5_grid(c(-3.19, 55.95, -3.189, 55.951), resolution = 8)
  expect_true(length(cells) >= 1L)
})

test_that("antimeridian-crossing bbox works", {
  # Fiji: bbox straddles the antimeridian (xmin > xmax)
  cells <- a5_grid(c(177, -19, -178, -17), resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) > 0)
  expect_true(all(a5_get_resolution(cells) == 5L))
  # cells on both sides of the antimeridian
  centres <- a5_cell_to_lonlat(cells)
  lons <- wk::wk_coords(centres)$x
  expect_true(any(lons > 0))
  expect_true(any(lons < 0))
})

test_that("near-pole bbox returns cells", {
  # Rust bbox grid skips filtering near poles (buf >= 45) to avoid false negatives
  cells <- a5_grid(c(0, 89.999, 0.001, 90), resolution = 5)
  expect_s3_class(cells, "a5_cell")
  expect_true(length(cells) >= 1L)
})
