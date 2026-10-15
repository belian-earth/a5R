#' A5 Cell Index Vector
#'
#' Create, test, and coerce A5 cell index vectors. Cells are stored as
#' a record with eight raw-byte fields (`b1`--`b8`) representing the
#' little-endian bytes of the u64 cell ID. This avoids the precision
#' loss of floating-point storage and keeps memory compact.
#'
#' Ids are hex strings of up to 16 digits, optionally prefixed with `0x`.
#' Shorter ids, as some A5 libraries write them, are padded with leading
#' zeros, and a string that is not a hex id is an error. `a5_cell()` does not
#' check that an id encodes an A5 cell, so an `a5_cell` vector can hold
#' values that are not cells. Check ids from outside sources, such as a file or a database, with
#' [a5_is_valid_cell()].
#'
#' @param x A character vector of hex-encoded A5 cell IDs, or an object
#'   coercible to one.
#' @returns An `a5_cell` vector (`a5_cell`, `as_a5_cell`), or a logical
#'   scalar (`is_a5_cell`).
#' @seealso [a5_is_valid_cell()] to check that values are A5 cells, and
#'   [a5_is_valid()] for any a5R object; [a5_u64_to_hex()] to convert back to
#'   hex strings; [a5_migrate()] for ids written by a5R before 1.0.
#'
#' @export
#' @examples
#' cells <- a5_cell(c("0800000000000006", "0800000000000016"))
#' cells
#' a5_is_valid_cell(cells)
#'
#' # a5_cell() does not validate: this value is not a cell
#' a5_is_valid_cell(a5_cell("fd00000000000000"))
a5_cell <- function(x = character()) {
  x <- vctrs::vec_cast(x, character())
  cells_from_rs(from_caller(hex_to_raw8_rs(x), call = rlang::current_env()))
}

new_a5_cell <- function(
  b1 = raw(),
  b2 = raw(),
  b3 = raw(),
  b4 = raw(),
  b5 = raw(),
  b6 = raw(),
  b7 = raw(),
  b8 = raw()
) {
  vctrs::new_rcrd(
    list(
      b1 = b1,
      b2 = b2,
      b3 = b3,
      b4 = b4,
      b5 = b5,
      b6 = b6,
      b7 = b7,
      b8 = b8
    ),
    class = "a5_cell"
  )
}

#' Construct an a5_cell from Rust list(b1=, ..., b8=) output
#'
#' The Rust side always returns a named list of eight equal-length raw
#' vectors, so the validation `vctrs::new_rcrd()` performs is redundant
#' here and dominates the cost of scalar calls. The result is identical
#' to `new_a5_cell()`.
#' @noRd
cells_from_rs <- function(x) {
  structure(x, class = c("a5_cell", "vctrs_rcrd", "vctrs_vctr"))
}

#' Pass cell fields to Rust as a named list
#' @noRd
cell_data <- function(x) {
  # The Rust side reads the eight raw fields by name; unclass() exposes them
  # directly, whereas vctrs::vec_data() builds a data frame for each call.
  unclass(x)
}

#' @export
#' @rdname a5_cell
is_a5_cell <- function(x) {
  inherits(x, "a5_cell")
}

#' @export
#' @rdname a5_cell
as_a5_cell <- function(x) {
  if (is_a5_cell(x)) {
    return(x)
  }
  if (is_a5_covering(x)) {
    cli::cli_abort(c(
      "Can't use an {.cls a5_covering} as cells.",
      "i" = "Use {.fn a5_uncompact} to get the cells of a covering."
    ), call = rlang::caller_env())
  }
  a5_cell(x)
}

#' Coerce between hex strings and A5 cell vectors
#'
#' `a5_u64_to_hex()` converts an [a5_cell] vector to 16-character
#' zero-padded hex strings. `a5_hex_to_u64()` converts hex strings to
#' an [a5_cell] vector.
#'
#' @param x For `a5_u64_to_hex()`, an [a5_cell] vector (or object
#'   coercible to one). For `a5_hex_to_u64()`, a character vector of
#'   hex-encoded cell IDs.
#' @returns `a5_u64_to_hex()` returns a character vector. `a5_hex_to_u64()`
#'   returns an [a5_cell] vector.
#'
#' @details
#' These are named to match `u64_to_hex` / `hex_to_u64` in the upstream
#' Python, JavaScript, and DuckDB A5 bindings. In those languages the
#' functions convert between a native 64-bit unsigned integer and its hex
#' representation. Because R has no native `uint64` type, `a5_u64_to_hex()`
#' accepts an [a5_cell] (which stores the `u64` internally as eight raw
#' bytes) instead of a bare integer.
#'
#' @seealso [a5_cell_from_arrow()] and [a5_cell_to_arrow()] for lossless
#'   conversion between [a5_cell] and Arrow `uint64` arrays.
#'
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' hex <- a5_u64_to_hex(cell)
#' hex
#'
#' a5_hex_to_u64(hex)
a5_u64_to_hex <- function(x) {
  x <- as_a5_cell(x)
  raw8_to_hex_rs(cell_data(x))
}

#' @rdname a5_u64_to_hex
#' @export
a5_hex_to_u64 <- function(x) {
  a5_cell(x)
}

# --- vctrs methods ---

#' @exportS3Method vctrs::vec_ptype_abbr
#' @noRd
#' @keywords internal
vec_ptype_abbr.a5_cell <- function(x, ...) "a5_cell"

#' @exportS3Method vctrs::vec_ptype_full
#' @noRd
#' @keywords internal
vec_ptype_full.a5_cell <- function(x, ...) "a5_cell"

#' @export
#' @noRd
#' @keywords internal
format.a5_cell <- function(x, ...) {
  raw8_to_hex_rs(cell_data(x))
}

#' @export
#' @noRd
#' @keywords internal
is.na.a5_cell <- function(x) {
  # NA is the full id 0xFC00000000000000, stored as eight 00 bytes because
  # b8 is stored XOR 0xFC (see src/rust/src/cell_raw.rs). A top byte of 0xFC
  # alone is a valid resolution-30 cell, so all eight bytes are checked.
  cells_is_na_rs(cell_data(x))
}

# --- equality and ordering in u64 numeric order ---

#' Two exact 32-bit halves of each id as doubles, `NA` for `NA` cells
#'
#' Raw fields cannot hold `NA`, so without this proxy vctrs would treat `NA`
#' cells (stored as eight 00 bytes) as an ordinary value: `==` would return
#' `TRUE` against `NA`, `vec_detect_missing()` `FALSE`, and sorting would place
#' `NA` among resolution-30 cells. The halves compare in u64 numeric order.
#' @noRd
cell_proxy <- function(x) {
  vctrs::new_data_frame(cells_proxy_rs(unclass(x)))
}

#' @exportS3Method vctrs::vec_proxy_equal
#' @noRd
#' @keywords internal
vec_proxy_equal.a5_cell <- function(x, ...) {
  cell_proxy(x)
}

#' @exportS3Method vctrs::vec_proxy_compare
#' @noRd
#' @keywords internal
vec_proxy_compare.a5_cell <- function(x, ...) {
  cell_proxy(x)
}

#' @exportS3Method vctrs::vec_proxy_order
#' @noRd
#' @keywords internal
vec_proxy_order.a5_cell <- function(x, ...) {
  cell_proxy(x)
}

# --- coercion: a5_cell <-> character ---

#' @export
#' @noRd
#' @keywords internal
vec_ptype2.a5_cell.a5_cell <- function(x, y, ...) new_a5_cell()

#' @export
#' @noRd
#' @keywords internal
vec_ptype2.a5_cell.character <- function(x, y, ...) new_a5_cell()

#' @export
#' @noRd
#' @keywords internal
vec_ptype2.character.a5_cell <- function(x, y, ...) new_a5_cell()

#' @export
#' @noRd
#' @keywords internal
vec_cast.a5_cell.a5_cell <- function(x, to, ...) x

#' @export
#' @noRd
#' @keywords internal
vec_cast.a5_cell.character <- function(x, to, ...) {
  cells_from_rs(hex_to_raw8_rs(x))
}

#' @export
#' @noRd
#' @keywords internal
vec_cast.character.a5_cell <- function(x, to, ...) {
  raw8_to_hex_rs(cell_data(x))
}

# --- pillar formatting for tibbles ---

#' @exportS3Method pillar::pillar_shaft
#' @noRd
#' @keywords internal
pillar_shaft.a5_cell <- function(x, ...) {
  out <- format(x)
  pillar::new_pillar_shaft_simple(out, align = "left")
}
