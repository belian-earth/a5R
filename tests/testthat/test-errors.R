test_that("errors carry a5R classes", {
  cell <- a5_lonlat_to_cell(0, 0, 5)
  expect_error(a5_lonlat_to_cell(0, 91, 5), class = "a5R_error_geometry")
  expect_error(a5_lonlat_to_cell(0, 0, 31), class = "a5R_error_resolution")
  expect_error(a5_cell_to_parent(cell, 6), class = "a5R_error_resolution")
  expect_error(a5_cell_to_children(cell, NA), class = "a5R_error_resolution")
  expect_error(a5_cell("zz"), class = "a5R_error_cell")
  expect_error(vctrs::vec_cast("zz", a5_cell()), class = "a5R_error_cell")
  expect_error(a5_grid_disk(cell, -1), class = "a5R_error_argument")
  expect_error(
    a5_polygon_to_cells(wk::wkt("POLYGON ((0 0, 1 0, 1 95, 0 0))"), 4),
    class = "a5R_error_geometry"
  )
  expect_error(
    a5_uncompact(as_a5_covering(a5_get_res0_cells()), 20),
    class = "a5R_error_size"
  )
  # every class is also an a5R_error
  expect_error(a5_cell("zz"), class = "a5R_error")
})
