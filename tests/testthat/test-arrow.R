test_that("a5_cell_to_arrow returns uint64 array", {
  skip_if_not_installed("arrow")
  cells <- a5_lonlat_to_cell(c(-3.19, 135, -60), c(55.95, 0, 45), 10)
  arr <- a5_cell_to_arrow(cells)
  expect_s3_class(arr, "Array")
  expect_equal(arr$type$ToString(), "uint64")
  expect_equal(arr$length(), 3L)
})

test_that("a5_cell_from_arrow rejects non-uint64", {
  skip_if_not_installed("arrow")
  arr <- arrow::Array$create(1:3, type = arrow::int32())
  expect_error(a5_cell_from_arrow(arr), "uint64")
})

test_that("round-trip a5_cell -> arrow -> a5_cell is lossless", {
  skip_if_not_installed("arrow")
  # Include cells with bit 63 set (origin >= 6) — these exceed 2^53
  cells <- a5_lonlat_to_cell(
    c(-3.19, 135, -60, 0, 179),
    c(55.95, 0, 45, 0, -89),
    resolution = 10
  )
  arr <- a5_cell_to_arrow(cells)
  back <- a5_cell_from_arrow(arr)
  expect_equal(format(back), format(cells))
})

test_that("round-trip preserves cells across all origins", {
  skip_if_not_installed("arrow")
  # Systematically test points that hit different icosahedron faces
  lons <- seq(-180, 170, by = 30)
  lats <- rep(c(-45, 0, 45), length.out = length(lons))
  cells <- a5_lonlat_to_cell(lons, lats, resolution = 15)
  arr <- a5_cell_to_arrow(cells)
  back <- a5_cell_from_arrow(arr)
  expect_equal(format(back), format(cells))
})

test_that("NA round-trips through arrow", {
  skip_if_not_installed("arrow")
  cells <- a5_cell(c("0800000000000006", NA, "633e000000000000"))
  arr <- a5_cell_to_arrow(cells)
  expect_true(arr$IsNull(1))
  expect_false(arr$IsNull(0))
  back <- a5_cell_from_arrow(arr)
  expect_equal(format(back), format(cells))
  expect_true(is.na(back[2]))
})

test_that("a5_cell_from_arrow handles ChunkedArray", {
  skip_if_not_installed("arrow")
  cells <- a5_lonlat_to_cell(c(0, 135), c(0, 0), 10)
  arr <- a5_cell_to_arrow(cells)
  chunked <- arrow::chunked_array(arr, arr)
  back <- a5_cell_from_arrow(chunked)
  expect_length(back, 4L)
  expect_equal(format(back), rep(format(cells), 2))
})

test_that("parquet round-trip is lossless", {
  skip_if_not_installed("arrow")
  cells <- a5_lonlat_to_cell(
    c(-3.19, 135, -60, 0, 179),
    c(55.95, 0, 45, 0, -89),
    resolution = 10
  )

  tf <- tempfile(fileext = ".parquet")
  on.exit(unlink(tf))

  # Write
  tbl <- arrow::arrow_table(cell_id = a5_cell_to_arrow(cells))
  arrow::write_parquet(tbl, tf)

  # Read
  back_tbl <- arrow::read_parquet(tf, as_data_frame = FALSE)
  back_cells <- a5_cell_from_arrow(back_tbl$column(0))
  expect_equal(format(back_cells), format(cells))
})

test_that("high resolution survives parquet round-trip", {
  skip_if_not_installed("arrow")
  # High resolution uses many bits of the u64
  cells <- a5_lonlat_to_cell(c(-60, 135, 0), c(45, 0, 0), resolution = 20)
  arr <- a5_cell_to_arrow(cells)
  back <- a5_cell_from_arrow(arr)
  expect_equal(format(back), format(cells))
  expect_true(all(a5_get_resolution(back) == 20L))
})

test_that("resolution 29 round-trips through arrow (vectorised)", {
  skip_if_not_installed("arrow")
  # res 29 uses nearly every bit of the u64 — precision stress test
  # (res 30 has an upstream bug in the a5 crate)
  lons <- seq(-180, 170, by = 10)
  lats <- rep(c(-80, -40, 0, 40, 80), length.out = length(lons))
  cells <- a5_lonlat_to_cell(lons, lats, resolution = 29)
  expect_true(all(a5_get_resolution(cells) == 29L))
  arr <- a5_cell_to_arrow(cells)
  back <- a5_cell_from_arrow(arr)
  expect_equal(format(back), format(cells))
})

test_that("sliced arrays with nulls convert at any offset", {
  skip_if_not_installed("arrow")
  cells <- a5_lonlat_to_cell(seq(-170, 170, length.out = 20), 10, 12)
  cells[c(2, 9, 10, 17)] <- NA
  arr <- a5_cell_to_arrow(cells)
  expect_identical(arr$null_count, 4L)
  for (offset in c(1L, 3L, 8L, 9L)) {
    back <- a5_cell_from_arrow(arr$Slice(offset, 9L))
    expect_identical(format(back), format(cells[offset + 1:9]))
  }
  # buffers allocated by Arrow itself, not by a5R
  copied <- arrow::concat_arrays(arr$Slice(5L), arr$Slice(0L, 5L))
  expect_identical(format(a5_cell_from_arrow(copied)), format(cells[c(6:20, 1:5)]))
})

test_that("empty arrays and chunked arrays convert", {
  skip_if_not_installed("arrow")
  arr <- a5_cell_to_arrow(a5_cell())
  expect_identical(arr$length(), 0L)
  expect_identical(arr$type$ToString(), "uint64")
  expect_length(a5_cell_from_arrow(arr), 0L)
  expect_length(a5_cell_from_arrow(arrow::chunked_array(type = arrow::uint64())), 0L)
})

test_that("exported arrays outlive the cells they came from", {
  skip_if_not_installed("arrow")
  cells <- a5_lonlat_to_cell(c(0, 135), c(0, 0), 10)
  expected <- format(cells)
  arr <- a5_cell_to_arrow(cells)
  rm(cells)
  gc()
  expect_identical(format(a5_cell_from_arrow(arr)), expected)
})

test_that("non-Arrow input gets a clear error", {
  skip_if_not_installed("arrow")
  expect_error(a5_cell_from_arrow(1:3), "Arrow <Array> or <ChunkedArray>")
  expect_error(a5_covering_from_arrow(list()), "Arrow <Array> or <ChunkedArray>")
  na <- structure(list(), class = "nanoarrow_array")
  expect_error(a5_cell_from_arrow(na), "as_arrow_array")
})

test_that("data frames round-trip through Arrow tables and Parquet", {
  skip_if_not_installed("arrow")
  cells <- a5_lonlat_to_cell(c(-3.19, 135, 0), c(55.95, 0, 0), 10)
  cells[3] <- NA
  df <- data.frame(cell = cells, value = c(1.5, 2.5, NA), name = c("a", "b", "c"))
  df$disk <- a5_grid_disk(cells, k = 1)
  tbl <- a5_to_arrow_table(df)
  expect_identical(tbl$metadata[["a5:index_version"]], a5_index_version())
  expect_identical(tbl$schema$cell$type$ToString(), "uint64")
  back <- a5_from_arrow_table(tbl)
  expect_identical(back$cell, df$cell)
  expect_identical(back$disk, df$disk)
  expect_identical(back$value, df$value)
  expect_identical(back$name, df$name)

  f <- withr::local_tempfile(fileext = ".parquet")
  arrow::write_parquet(tbl, f)
  back2 <- a5_from_arrow_table(arrow::read_parquet(f, as_data_frame = FALSE))
  expect_identical(back2$cell, df$cell)
  expect_identical(back2$disk, df$disk)

  # only the named columns become cells
  plain <- a5_from_arrow_table(tbl, cells = character(), coverings = character())
  expect_false(is_a5_cell(plain$cell))
  expect_error(a5_from_arrow_table(tbl, cells = "nope"), class = "a5R_error_argument")
})

test_that("a table tagged with another index version is refused", {
  skip_if_not_installed("arrow")
  tbl <- a5_to_arrow_table(data.frame(cell = a5_lonlat_to_cell(0, 0, 5)))
  tbl$metadata[["a5:index_version"]] <- "0"
  expect_error(a5_from_arrow_table(tbl), class = "a5R_error_cell")
  # untagged tables are read as they are
  tbl$metadata[["a5:index_version"]] <- NULL
  expect_true(is_a5_cell(a5_from_arrow_table(tbl)$cell))
})
