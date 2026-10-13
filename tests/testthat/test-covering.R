cells <- a5_lonlat_to_cell(c(-3.19, 0, 139.7), c(55.95, 0, 35.69), resolution = 8)
disks <- a5_grid_disk(cells, k = 3)

test_that("a5_covering behaves as a vector of coverings", {
  expect_true(is_a5_covering(disks))
  expect_false(is_a5_covering(cells))
  expect_length(disks, 3L)
  expect_identical(disks[[2]], disks[2])
  expect_identical(c(disks[1], disks[3]), disks[c(1, 3)])
  expect_identical(vctrs::vec_c(disks[1], disks[2:3]), disks)
  expect_identical(rev(rev(disks)), disks)
  expect_identical(disks == disks[1], c(TRUE, FALSE, FALSE))
  expect_identical(vctrs::vec_unique(c(disks, disks)), disks)
  expect_identical(vctrs::vec_ptype_abbr(disks), "a5_covering")
})

test_that("missing coverings are NA", {
  x <- c(disks[1], a5_grid_disk(a5_cell(NA), k = 1))
  expect_identical(is.na(x), c(FALSE, TRUE))
  expect_identical(a5_covering_resolution(x), c(8L, NA))
  expect_true(is.na(format(x)[2]))
  y <- disks
  y[2] <- NA
  expect_identical(is.na(y), c(FALSE, TRUE, FALSE))
  expect_identical(is.na(vctrs::vec_init(disks, 2)), c(TRUE, TRUE))
})

test_that("format shows resolution, cells and stored cells", {
  kids <- a5_cell_to_children(cells[1], resolution = 10)
  expect_identical(format(a5_compact(kids)), "res 10: 16 cells (1 stored)")
  expect_identical(format(a5_compact(kids[1])), "res 10: 1 cell (1 stored)")
  expect_identical(format(a5_compact(a5_cell(), resolution = 3)), "res 3: empty")
  expect_identical(format(a5_compact(a5_cell("0000000000000000"))), "world")
  expect_snapshot(print(disks))
})

test_that("coverings work as tibble columns", {
  skip_if_not_installed("tibble")
  df <- tibble::tibble(cell = cells, disk = disks)
  expect_identical(df$disk, disks)
  expect_snapshot(print(df))
  expect_identical(vctrs::vec_rbind(df, df)$disk, c(disks, disks))
})

test_that("as_a5_covering builds coverings from cells and cell lists", {
  expect_identical(as_a5_covering(disks), disks)
  expect_identical(as_a5_covering(a5_uncompact(disks[1])), disks[1])
  lst <- a5_uncompact(disks, simplify = FALSE)
  expect_identical(as_a5_covering(lst), disks)
  expect_identical(as_a5_covering(unclass(lst)), disks)
  expect_identical(a5_covering_resolution(as_a5_covering(lst, resolution = 9)), rep(9L, 3))
  expect_error(as_a5_covering(1:3), "Can't convert")
})

test_that("as_a5_covering normalises raw coverings from other libraries", {
  stored <- unclass(disks)
  # dropping the marker: the finest cell's resolution
  no_marker <- lapply(stored, function(r) r[seq_len(length(r) - 8L)])
  expect_identical(as_a5_covering(no_marker), disks)
  # reversed order: sorted again
  values <- lapply(no_marker, function(r) {
    split(r, rep(seq_len(length(r) / 8), each = 8)) |> rev() |> unlist(use.names = FALSE)
  })
  expect_identical(as_a5_covering(values), disks)
  # a missing element stays missing; an explicit resolution re-records
  expect_identical(is.na(as_a5_covering(list(stored[[1]], NULL))), c(FALSE, TRUE))
  expect_identical(
    a5_covering_resolution(as_a5_covering(no_marker, resolution = 10)),
    rep(10L, 3)
  )
  # a marker always wins over the requested resolution
  expect_identical(as_a5_covering(stored, resolution = 10), disks)
  expect_error(as_a5_covering(list(as.raw(1:7))), "multiple of 8")
  expect_error(
    as_a5_covering(list(rep(as.raw(0x40), 8))),
    "neither an A5 cell nor a compaction marker"
  )
})

test_that("a5_is_valid checks covering structure", {
  stored <- unclass(disks)
  expect_identical(a5_is_valid(disks), rep(TRUE, 3))
  bytes <- stored[[1]]
  n <- length(bytes) / 8
  piece <- function(i) bytes[(8 * (i - 1) + 1):(8 * i)]
  unsorted <- c(piece(2), piece(1), unlist(lapply(3:n, piece)))
  overlapping <- c(piece(1), unlist(lapply(seq_len(n), piece)))
  invalid <- c(rep(as.raw(0x40), 8), bytes)
  hand_made <- coverings_from_rs(list(unsorted, overlapping, invalid, NULL))
  expect_identical(a5_is_valid(hand_made), c(FALSE, FALSE, FALSE, NA))
})

test_that("coverings round-trip through Arrow list<uint64>", {
  skip_if_not_installed("arrow")
  x <- c(disks, a5_grid_disk(a5_cell(NA), k = 1), a5_compact(a5_cell(), resolution = 4))
  arr <- a5_covering_to_arrow(x)
  expect_identical(arr$type$ToString(), "list<item: uint64>")
  expect_identical(arr$null_count, 1L)
  expect_identical(a5_covering_from_arrow(arr), x)
  chunked <- arrow::chunked_array(arr$Slice(0, 2), arr$Slice(2))
  expect_identical(a5_covering_from_arrow(chunked), x)
  # the compaction marker is stored after the cells
  stored <- a5_covering_summary_rs(disks)$stored
  expect_identical(lengths(as.vector(arr))[1:3], stored + 1L)
  marker_8 <- as.raw(c(0x40, 0, 0, 0, 0, 0, 0x08, 0xf0)) # 0xf008000000000040
  expect_identical(utils::tail(unclass(disks)[[1]], 8), marker_8)
  expect_error(a5_covering_from_arrow(a5_cell_to_arrow(cells)), "list<uint64>")
})
