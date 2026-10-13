# fixtures/migrate-v0.csv: cells indexed from random points by a5R 0.6.0.9001
# (a5 crate 0.10.0, the v0 index), with each cell's centre. Seven cells per
# resolution, 0 to 30.
v0_fixture <- function() {
  utils::read.csv(
    test_path("fixtures", "migrate-v0.csv"),
    colClasses = c("integer", "character", "numeric", "numeric")
  )
}

great_circle <- function(lon1, lat1, lon2, lat2) {
  rad <- pi / 180
  a <- sin((lat2 - lat1) * rad / 2)^2 +
    cos(lat1 * rad) * cos(lat2 * rad) * sin((lon2 - lon1) * rad / 2)^2
  2 * 6371008.8 * asin(pmin(1, sqrt(a)))
}

test_that("migrate matches the upstream example", {
  expect_identical(
    format(a5_migrate(a5_cell("59c4780000000000"))),
    "59c4280000000000"
  )
})

test_that("migrated ids are the cells the v1 index gives their centres", {
  fx <- v0_fixture()
  migrated <- a5_migrate(a5_cell(fx$v0))
  expect_true(all(a5_is_valid_cell(migrated)))
  expect_identical(a5_get_resolution(migrated), fx$resolution)
  expect_identical(migrated, a5_lonlat_to_cell(fx$lon, fx$lat, fx$resolution))
})

test_that("migration keeps every cell in place", {
  # Resolution-1 cells changed shape in a5 1.0 (triangles became pentagons,
  # a5-rs #68), so their centres moved; the cell holding the old centre is
  # still the migrated id (tested above).
  fx <- v0_fixture()
  fx <- fx[fx$resolution != 1L, ]
  ctr <- a5_cell_to_lonlat(a5_migrate(a5_cell(fx$v0)), as_dataframe = TRUE)
  expect_lt(max(great_circle(ctr$lon, ctr$lat, fx$lon, fx$lat)), 1e-6)
})

test_that("migrate passes NA and the world cell through", {
  out <- a5_migrate(a5_cell(c(NA, "0000000000000000")))
  expect_identical(format(out), c(NA, "0000000000000000"))
})
