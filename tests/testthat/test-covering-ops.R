edinburgh <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 12)
glasgow <- a5_lonlat_to_cell(-4.25, 55.86, resolution = 12)
caps <- a5_spherical_cap(c(edinburgh, glasgow), radius = 40000)
a <- a5_uncompact(caps[1])
b <- a5_uncompact(caps[2])

test_that("set operations match the expanded cell sets", {
  expect_identical(a5_uncompact(a5_union(caps[1], caps[2])),
                   vctrs::vec_sort(vctrs::vec_unique(c(a, b))))
  expect_identical(a5_uncompact(a5_intersect(caps[1], caps[2])),
                   a[vctrs::vec_in(a, b)])
  expect_identical(a5_uncompact(a5_difference(caps[1], caps[2])),
                   a[!vctrs::vec_in(a, b)])
  expect_gt(length(a5_uncompact(a5_intersect(caps[1], caps[2]))), 0L)
})

test_that("set operation results are compacted coverings", {
  u <- a5_union(caps[1], caps[2])
  expect_s3_class(u, "a5_covering")
  expect_identical(u, a5_compact(c(a, b)))
  expect_true(a5_is_valid(u))
  expect_identical(a5_covering_resolution(u), 12L)
})

test_that("set operations recycle and propagate NA", {
  cell8 <- a5_lonlat_to_cell(c(0, 1, NA), c(0, 1, NA), resolution = 8)
  disks <- a5_grid_disk(cell8, k = 2)
  big <- a5_grid_disk(cell8[1], k = 6)
  out <- a5_intersect(disks, big)
  expect_length(out, 3L)
  expect_identical(out[1], disks[1])
  expect_identical(is.na(out), c(FALSE, FALSE, TRUE))
  expect_identical(a5_union(big, disks)[1], big)
  expect_error(a5_union(disks, c(disks, disks)), "recycle")
})

test_that("a5_union(x) merges every covering, skipping NA", {
  x <- c(caps, a5_spherical_cap(a5_cell(NA), radius = 1))
  expect_identical(a5_union(x), a5_union(caps[1], caps[2]))
  expect_identical(a5_union(caps[1]), caps[1])
  expect_length(a5_uncompact(a5_union(a5_compact(a5_cell())[0])), 0L)
})

test_that("combining coverings at different resolutions is an error", {
  disk8 <- a5_grid_disk(a5_lonlat_to_cell(-3.19, 55.95, resolution = 8), k = 1)
  expect_error(a5_union(caps[1], disk8), "resolution 12 with cells at resolution 8")
  expect_error(a5_intersect(caps, disk8), "element 1")
  expect_error(a5_overlaps(caps[1], disk8), "resolution")
  expect_error(a5_union(c(caps, disk8)), "resolution")
})

test_that("an empty covering without a resolution is the empty set", {
  nothing <- a5_compact(a5_cell())
  expect_identical(a5_union(nothing, caps[1]), caps[1])
  expect_identical(a5_union(caps[1], nothing), caps[1])
  expect_length(a5_uncompact(a5_intersect(caps[1], nothing)), 0L)
  expect_identical(a5_difference(caps[1], nothing), caps[1])
  expect_false(a5_overlaps(caps[1], nothing))
  expect_false(a5_contains(nothing, edinburgh))
})

test_that("contains is a point-in-covering test at the covering's resolution", {
  inside <- a[c(1, length(a))]
  outside <- b[!vctrs::vec_in(b, a)][1:2]
  expect_identical(a5_contains(caps[1], c(inside, outside, a5_cell(NA))),
                   c(TRUE, TRUE, FALSE, FALSE, NA))
  expect_identical(a5_contains(caps[1], a), rep(TRUE, length(a)))
  # row by row
  expect_identical(a5_contains(caps, c(edinburgh, edinburgh)), c(TRUE, FALSE))
  expect_error(a5_contains(caps[1], a5_cell_to_parent(edinburgh)), "resolution 11")
})

test_that("contains agrees with polygon point tests", {
  poly <- wk::wkt("POLYGON ((-3.4 55.85, -3 55.85, -3 56.05, -3.4 56.05, -3.4 55.85))")
  covering <- a5_polygon_to_cells(poly, resolution = 12)
  withr::with_seed(1, {
    lon <- stats::runif(500, -3.5, -2.9)
    lat <- stats::runif(500, 55.8, 56.1)
  })
  pts <- a5_lonlat_to_cell(lon, lat, resolution = 12)
  expect_identical(a5_contains(covering, pts), vctrs::vec_in(pts, a5_uncompact(covering)))
})

test_that("overlaps detects shared cells", {
  far <- a5_spherical_cap(a5_lonlat_to_cell(10, 10, resolution = 12), radius = 1000)
  expect_identical(a5_overlaps(caps, caps[1]), c(TRUE, TRUE))
  expect_identical(a5_overlaps(caps, far), c(FALSE, FALSE))
  expect_identical(a5_overlaps(caps[1], a5_grid_disk(a5_cell(NA), k = 1)), NA)
})

test_that("count and area measure the cells a covering stands for", {
  expect_identical(a5_count(caps), c(length(a), length(b)) + 0)
  expect_equal(a5_area(caps, units = NULL), a5_count(caps) * a5_cell_area(12, units = NULL))
  expect_s3_class(a5_area(caps), "units")
  expect_equal(as.numeric(a5_area(caps, "km^2")), a5_area(caps, NULL) / 1e6)
  expect_identical(a5_count(a5_grid_disk(a5_cell(NA), k = 1)), NA_real_)
  expect_identical(a5_count(a5_compact(a5_cell(), resolution = 5)), 0)
  # beyond 2^53: the whole globe at resolution 30
  world30 <- a5_compact(a5_get_res0_cells(), resolution = 30)
  expect_equal(a5_count(world30), a5_get_num_cells(30))
  expect_equal(as.numeric(a5_area(world30, "km^2")), 4 * pi * 6371.0072^2, tolerance = 1e-4)
  expect_error(a5_area(caps, units = "m"), "area unit")
})

test_that("covering operations are identical with threads > 1", {
  skip_if(parallel::detectCores() < 2)
  old <- a5_get_threads()
  on.exit(a5_set_threads(old))
  cells <- a5_lonlat_to_cell(seq(-10, 10, length.out = 50), 50, resolution = 10)
  disks <- a5_grid_disk(cells, k = 4)
  a5_set_threads(1L)
  single <- list(a5_union(disks, disks[1]), a5_contains(disks, cells), a5_overlaps(disks, disks[2]))
  a5_set_threads(2L)
  expect_identical(
    list(a5_union(disks, disks[1]), a5_contains(disks, cells), a5_overlaps(disks, disks[2])),
    single
  )
})
