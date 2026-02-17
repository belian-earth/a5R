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

test_that("result cells intersect the target", {
  bbox <- c(-3.3, 55.9, -3.1, 56.0)
  cells <- a5_grid(bbox, resolution = 5)
  boundaries <- a5_cell_to_boundary(cells)
  cell_geoms <- geos::as_geos_geometry(boundaries)
  target <- geos::as_geos_geometry(
    wk::rct(bbox[1], bbox[2], bbox[3], bbox[4], crs = wk::wk_crs_longlat())
  )
  expect_true(all(geos::geos_intersects(cell_geoms, target)))
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

test_that("empty intermediate result warns and returns empty a5_cell", {
  # Very small bbox near the pole — planar filtering can prune all cells at
  # intermediate resolutions. This must warn and return an empty vector,
  # not crash in Rust (which panics on empty input to a5_uncompact).
  expect_warning(
    cells <- a5_grid(c(0, 89.999, 0.001, 90), resolution = 5),
    "No cells found"
  )
  expect_s3_class(cells, "a5_cell")
  expect_length(cells, 0L)
})
