#' A5 Cell Index Vector
#'
#' Create, test, and coerce A5 cell index vectors. Cells are stored as
#' a record with eight raw-byte fields (`b1`--`b8`) representing the
#' little-endian bytes of the u64 cell ID. This avoids the precision
#' loss of floating-point storage and keeps memory compact.
#'
#' @param x A character vector of hex-encoded A5 cell IDs, or an object
#'   coercible to one.
#' @returns An `a5_cell` vector (`a5_cell`, `as_a5_cell`), a logical
#'   scalar (`is_a5_cell`), or a logical vector (`a5_is_valid`).
#'
#' @export
#' @examples
#' cells <- a5_cell(c("0800000000000006", "0800000000000016"))
#' cells
a5_cell <- function(x = character()) {
  x <- vctrs::vec_cast(x, character())
  check_hex16(x)
  rs <- hex_to_raw8_rs(x)
  cells_from_rs(rs)
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
#' @noRd
cells_from_rs <- function(x) {
  new_a5_cell(
    b1 = x$b1,
    b2 = x$b2,
    b3 = x$b3,
    b4 = x$b4,
    b5 = x$b5,
    b6 = x$b6,
    b7 = x$b7,
    b8 = x$b8
  )
}

#' Check that all non-NA hex strings are exactly 16 characters
#' @noRd
check_hex16 <- function(x) {
  non_na <- !is.na(x)
  bad <- non_na & nchar(x) != 16L
  if (any(bad)) {
    first <- x[which(bad)[1L]]
    cli::cli_abort(
      "Cell hex strings must be exactly 16 characters, not {nchar(first)}. {.val {first}} is invalid."
    )
  }
}

#' Pass cell fields to Rust as a named list
#' @noRd
cell_data <- function(x) {
  vctrs::vec_data(x)
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
  a5_cell(x)
}

#' @export
#' @rdname a5_cell
#' @examples
#' a5_is_valid(c("0800000000000006", "not_a_cell", NA))
a5_is_valid <- function(x) {
  if (is_a5_cell(x)) {
    a5_is_valid_cell_rs(cell_data(x))
  } else {
    x <- vctrs::vec_cast(x, character())
    a5_is_valid_hex_rs(x)
  }
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
  # NA sentinel: last byte (b8) == 0xFC
  vctrs::field(x, "b8") == as.raw(0xFC)
}

# --- ordering: big-endian byte order = u64 numeric order ---

#' @exportS3Method vctrs::vec_proxy_compare
#' @noRd
#' @keywords internal
vec_proxy_compare.a5_cell <- function(x, ...) {
  data.frame(
    b8 = as.integer(vctrs::field(x, "b8")),
    b7 = as.integer(vctrs::field(x, "b7")),
    b6 = as.integer(vctrs::field(x, "b6")),
    b5 = as.integer(vctrs::field(x, "b5")),
    b4 = as.integer(vctrs::field(x, "b4")),
    b3 = as.integer(vctrs::field(x, "b3")),
    b2 = as.integer(vctrs::field(x, "b2")),
    b1 = as.integer(vctrs::field(x, "b1"))
  )
}

#' @exportS3Method vctrs::vec_proxy_order
#' @noRd
#' @keywords internal
vec_proxy_order.a5_cell <- function(x, ...) {
  vec_proxy_compare.a5_cell(x, ...)
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
  check_hex16(x)
  rs <- hex_to_raw8_rs(x)
  cells_from_rs(rs)
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
