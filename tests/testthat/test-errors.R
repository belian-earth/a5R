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

test_that("invalid cells error as in the crate, naming the user's call", {
  bad <- a5_cell(c("fd00000000000000", NA))
  ok <- a5_lonlat_to_cell(0, 0, 5)
  for (f in list(
    function(x) a5_cell_to_lonlat(x),
    function(x) a5_cell_to_boundary(x),
    function(x) a5_cell_to_boundary(x, format = "wkt"),
    function(x) a5_cell_to_boundary_xy(x),
    function(x) a5_cell_to_supercell(x, 0)
  )) {
    expect_error(f(c(ok, bad)), "Invalid cell", class = "a5R_error_cell")
    expect_no_error(f(c(ok, a5_cell(NA))))
  }
  expect_error(a5_cell_to_lonlat(bad), "^cell_to_lonlat failed")
  err <- tryCatch(a5_cell_to_boundary(bad), error = identity)
  expect_identical(conditionCall(err)[[1]], quote(a5_cell_to_boundary))
})

test_that("invalid cells error with threads too", {
  old <- a5_set_threads(2L)
  on.exit(a5_set_threads(old))
  cells <- c(a5_lonlat_to_cell(runif(5000, -180, 180), runif(5000, -80, 80), 9),
             a5_cell("fd00000000000000"))
  expect_error(a5_cell_to_lonlat(cells), class = "a5R_error_cell")
  expect_error(a5_cell_to_boundary_xy(cells), class = "a5R_error_cell")
})
