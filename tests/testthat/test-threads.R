test_that("default threads is 1", {
    expect_equal(a5_get_threads(), 1L)
})

test_that("set/get threads works", {
    withr::defer(a5_set_threads(1L))
    old <- a5_set_threads(2L)
    expect_equal(old, 1L)
    expect_equal(a5_get_threads(), 2L)
})

test_that("results are identical with 1 vs 2 threads", {
    withr::defer(a5_set_threads(1L))
    cells <- a5_lonlat_to_cell(c(0, 10, -10), c(0, 20, -20), resolution = 5)

    a5_set_threads(1L)
    boundary_1 <- a5_cell_to_boundary(cells, format = "wkt")
    lonlat_1 <- a5_cell_to_lonlat(cells)
    parent_1 <- a5_cell_to_parent(cells)
    res_1 <- a5_get_resolution(cells)
    valid_1 <- a5_is_cell(cells)

    a5_set_threads(2L)
    boundary_2 <- a5_cell_to_boundary(cells, format = "wkt")
    lonlat_2 <- a5_cell_to_lonlat(cells)
    parent_2 <- a5_cell_to_parent(cells)
    res_2 <- a5_get_resolution(cells)
    valid_2 <- a5_is_cell(cells)

    expect_identical(as.character(boundary_1), as.character(boundary_2))
    expect_identical(lonlat_1, lonlat_2)
    expect_identical(as.character(parent_1), as.character(parent_2))
    expect_identical(res_1, res_2)
    expect_identical(valid_1, valid_2)
})
