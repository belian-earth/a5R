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

#' Convert data frames with cell columns to and from Arrow tables
#'
#' `a5_to_arrow_table()` converts a data frame to an Arrow `Table`, writing
#' [a5_cell] columns as `uint64` and [a5_covering] columns as `list<uint64>`
#' (see [a5_cell_to_arrow()] and [a5_covering_to_arrow()]), and records
#' the A5 index version (`a5_info()$index`) in the schema metadata under
#' `"a5:index_version"`.
#' `a5_from_arrow_table()` reverses it, turning `uint64` columns into cells
#' and `list<uint64>` columns into coverings.
#'
#' Ids stay exact throughout, never passing through doubles or text, so the
#' pair suits Parquet files and DuckDB queries. A table whose metadata
#' records a different index version is an error, since its ids would name
#' other cells; convert such ids with [a5_migrate()].
#'
#' @param x For `a5_to_arrow_table()`, a data frame. For
#'   `a5_from_arrow_table()`, an Arrow `Table`, `RecordBatch`, or anything
#'   [arrow::as_arrow_table()] accepts, such as a query result.
#' @param cells,coverings Names of the columns to read as cells and as
#'   coverings, or `NULL` (the default) for every `uint64` and every
#'   `list<uint64>` column respectively.
#' @returns `a5_to_arrow_table()`: an Arrow `Table`. `a5_from_arrow_table()`:
#'   a data frame.
#' @seealso [a5_info()]
#' @export
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
#' df <- data.frame(cell = cells, value = c(1.5, 2.5))
#' df$disk <- a5_grid_disk(cells, k = 1)
#' tbl <- a5_to_arrow_table(df)
#' tbl$schema
#' back <- a5_from_arrow_table(tbl)
#' identical(back$cell, df$cell)
a5_to_arrow_table <- function(x) {
  rlang::check_installed("arrow", reason = "to convert data frames to Arrow tables")
  if (!is.data.frame(x)) {
    a5_abort("argument", "{.arg x} must be a data frame, not {.obj_type_friendly {x}}.")
  }
  cols <- lapply(x, function(col) {
    if (is_a5_cell(col)) {
      a5_cell_to_arrow(col)
    } else if (is_a5_covering(col)) {
      a5_covering_to_arrow(col)
    } else {
      arrow::Array$create(col)
    }
  })
  tbl <- do.call(arrow::arrow_table, cols)
  tbl$metadata[["a5:index_version"]] <- A5_INDEX_VERSION
  tbl
}

#' @rdname a5_to_arrow_table
#' @export
a5_from_arrow_table <- function(x, cells = NULL, coverings = NULL) {
  rlang::check_installed("arrow", reason = "to convert Arrow tables to data frames")
  tbl <- arrow::as_arrow_table(x)
  version <- tbl$metadata[["a5:index_version"]]
  if (!is.null(version) && !identical(version, A5_INDEX_VERSION)) {
    a5_abort("cell", c(
      "{.arg x} holds ids from A5 index {version}, not {A5_INDEX_VERSION}.",
      "i" = "Convert pre-1.0 ids once with {.fn a5_migrate}."
    ))
  }
  types <- vapply(tbl$schema$fields, function(f) f$type$ToString(), character(1))
  names(types) <- names(tbl)
  if (is.null(cells)) cells <- names(types)[types == "uint64"]
  if (is.null(coverings)) coverings <- names(types)[grepl("^list<.*: uint64>$", types)]
  missing <- setdiff(c(cells, coverings), names(tbl))
  if (length(missing)) {
    a5_abort("argument", "{.arg x} has no column{?s} {.val {missing}}.")
  }
  out <- lapply(names(tbl), function(nm) {
    col <- tbl[[nm]]
    if (nm %in% cells) {
      a5_cell_from_arrow(col)
    } else if (nm %in% coverings) {
      a5_covering_from_arrow(col)
    } else {
      as.vector(col)
    }
  })
  names(out) <- names(tbl)
  vctrs::new_data_frame(out, n = tbl$num_rows)
}
