#' Convert between a5_cell and Arrow uint64 arrays
#'
#' Losslessly convert between [a5_cell] vectors and Arrow `uint64`
#' arrays. This avoids the precision loss that occurs when Arrow
#' converts `uint64` to R's `double` (which can only represent
#' integers exactly up to 2^53, while A5 cell IDs span the full
#' 0--2^64 range).
#'
#' @param x For `a5_cell_from_arrow()`, an Arrow `Array` or
#'   `ChunkedArray` of type `uint64`. For `a5_cell_to_arrow()`, an
#'   [a5_cell] vector.
#' @returns `a5_cell_from_arrow()` returns an [a5_cell] vector.
#'   `a5_cell_to_arrow()` returns an Arrow `Array` of type `uint64`.
#'
#' @details
#' The conversion runs in Rust and passes one contiguous `uint64` buffer
#' through the Arrow C data interface, so no value is ever converted to
#' `double`. NA cells are null elements. The resulting Arrow arrays can be
#' written directly to Parquet and read correctly by DuckDB, Python, and
#' other Arrow-compatible tools.
#'
#' @seealso [a5_u64_to_hex()] for converting to hex strings instead.
#'
#' @export
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' cell <- a5_lonlat_to_cell(135, 0, resolution = 10)
#' arr <- a5_cell_to_arrow(cell)
#' back <- a5_cell_from_arrow(arr)
#' identical(format(cell), format(back))
a5_cell_from_arrow <- function(x) {
  rlang::check_installed("arrow", reason = "to convert Arrow arrays to a5_cell")
  check_arrow_array(x)

  type_str <- x$type$ToString()
  if (!identical(type_str, "uint64")) {
    a5_abort("arrow", c(
      "Expected an Arrow {.code uint64} array.",
      "x" = "Got {.code {type_str}}."
    ))
  }

  slots <- arrow_slots(x)
  cells_from_rs(a5_cell_from_arrow_rs(slots$holder))
}

#' @rdname a5_cell_from_arrow
#' @export
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
#' arr <- a5_cell_to_arrow(cells)
#' arr$type$ToString()
a5_cell_to_arrow <- function(x) {
  rlang::check_installed("arrow", reason = "to convert a5_cell to Arrow arrays")
  x <- as_a5_cell(x)

  slots <- a5_cell_to_arrow_rs(cell_data(x))
  arrow::Array$import_from_c(slots$array, slots$schema)
}

#' Error unless `x` is an arrow `Array` or `ChunkedArray`
#' @noRd
check_arrow_array <- function(x, call = rlang::caller_env()) {
  if (!inherits(x, c("Array", "ChunkedArray"))) {
    a5_abort("arrow",
      c(
        "{.arg x} must be an Arrow {.cls Array} or {.cls ChunkedArray}, not {.obj_type_friendly {x}}.",
        i = if (inherits(x, "nanoarrow_array")) "Convert it with {.fn arrow::as_arrow_array}."
      ),
      call = call
    )
  }
  invisible(x)
}

#' Export every chunk of an Arrow array into Rust-owned C data interface
#' slots, ready for the `*_from_arrow_rs()` readers.
#' @noRd
arrow_slots <- function(x) {
  chunks <- if (inherits(x, "ChunkedArray")) x$chunks else list(x)
  slots <- arrow_slots_rs(length(chunks))
  for (i in seq_along(chunks)) {
    chunks[[i]]$export_to_c(slots$array[[i]], slots$schema[[i]])
  }
  slots
}

#' Convert between a5_covering and Arrow list<uint64> arrays
#'
#' Losslessly convert [a5_covering] vectors to and from Arrow
#' `list<uint64>` arrays, one list element per covering. Each element holds
#' the covering's compacted cells followed by its compaction marker, the
#' layout every A5 library uses, so the resolution travels with the data
#' into Parquet, DuckDB, Python or JavaScript. A missing covering is a null
#' element.
#'
#' `a5_covering_from_arrow()` accepts coverings written by any A5 library.
#' Each one is checked, sorted and compacted; an element without a
#' compaction marker stands for the resolution of its finest cell.
#'
#' @param x For `a5_covering_from_arrow()`, an Arrow `Array` or
#'   `ChunkedArray` of type `list<uint64>`. For `a5_covering_to_arrow()`, an
#'   [a5_covering] vector.
#' @returns `a5_covering_from_arrow()` returns an [a5_covering] vector.
#'   `a5_covering_to_arrow()` returns an Arrow `Array` of type
#'   `list<uint64>`.
#'
#' @seealso [a5_cell_to_arrow()] for single cells.
#' @export
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
#' disks <- a5_grid_disk(cells, k = 2)
#' arr <- a5_covering_to_arrow(disks)
#' arr$type$ToString()
#' identical(a5_covering_from_arrow(arr), disks)
a5_covering_from_arrow <- function(x) {
  rlang::check_installed("arrow", reason = "to convert Arrow arrays to a5_covering")
  check_arrow_array(x)
  type <- x$type
  if (!inherits(type, "ListType") || !identical(type$value_type$ToString(), "uint64")) {
    a5_abort("arrow", c(
      "Expected an Arrow {.code list<uint64>} array.",
      "x" = "Got {.code {type$ToString()}}."
    ))
  }
  slots <- arrow_slots(x)
  raws <- from_caller(a5_covering_from_arrow_rs(slots$holder), call = rlang::current_env())
  as_a5_covering(raws)
}

#' @rdname a5_covering_from_arrow
#' @export
a5_covering_to_arrow <- function(x) {
  rlang::check_installed("arrow", reason = "to convert a5_covering to Arrow arrays")
  x <- as_a5_covering(x)
  slots <- a5_covering_to_arrow_rs(x)
  arrow::Array$import_from_c(slots$array, slots$schema)
}
