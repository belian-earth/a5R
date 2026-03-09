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
#' Internally these use Arrow's zero-copy `View()` to reinterpret
#' `uint64` bytes as `fixed_size_binary(8)`, then convert to/from the
#' hi/lo double representation used by [a5_cell]. The resulting Arrow
#' arrays can be written directly to Parquet and read correctly by
#' DuckDB, Python, and other Arrow-compatible tools.
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

  type_str <- x$type$ToString()
  if (!identical(type_str, "uint64")) {
    cli::cli_abort(c(
      "Expected an Arrow {.code uint64} array.",
      "x" = "Got {.code {type_str}}."
    ))
  }

  # Handle ChunkedArray by processing each chunk
  if (inherits(x, "ChunkedArray")) {
    parts <- lapply(seq_len(x$num_chunks) - 1L, function(i) {
      chunk_to_a5(x$chunk(i))
    })
    return(do.call(vctrs::vec_c, parts))
  }

  chunk_to_a5(x)
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

  raw_list <- hilo_to_raw8_rs(
    vctrs::field(x, "hi"),
    vctrs::field(x, "lo")
  )

  bin_arr <- arrow::Array$create(raw_list, type = arrow::fixed_size_binary(8L))
  bin_arr$View(arrow::uint64())
}

#' Convert a single Arrow uint64 chunk to a5_cell
#' @noRd
chunk_to_a5 <- function(chunk) {
  fsb <- chunk$View(arrow::fixed_size_binary(8L))
  raw_list <- fsb$as_vector()
  hilo <- raw8_to_hilo_rs(raw_list)
  cells_from_rs(hilo)
}
