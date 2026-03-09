#' A5 Cell Index Vector
#'
#' Create, test, and coerce A5 cell index vectors. Cells are stored as
#' a record with two double fields (`hi`, `lo`) representing the upper
#' and lower 32-bit halves of the u64 cell ID. This avoids per-element
#' allocation overhead and keeps memory contiguous.
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
  hilo <- hex_to_hilo_rs(x)
  new_a5_cell(hi = hilo$hi, lo = hilo$lo)
}

new_a5_cell <- function(hi = double(), lo = double()) {
  vctrs::new_rcrd(list(hi = hi, lo = lo), class = "a5_cell")
}

#' Construct an a5_cell from Rust list(hi=, lo=) output
#' @noRd
cells_from_rs <- function(x) {
  new_a5_cell(hi = x$hi, lo = x$lo)
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
    a5_is_valid_cell_rs(vctrs::field(x, "hi"), vctrs::field(x, "lo"))
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
#' accepts an [a5_cell] (which stores the `u64` internally as two 32-bit
#' halves) instead of a bare integer.
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
  hilo_to_hex_rs(vctrs::field(x, "hi"), vctrs::field(x, "lo"))
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
  hilo_to_hex_rs(vctrs::field(x, "hi"), vctrs::field(x, "lo"))
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
  hilo <- hex_to_hilo_rs(x)
  new_a5_cell(hi = hilo$hi, lo = hilo$lo)
}

#' @export
#' @noRd
#' @keywords internal
vec_cast.character.a5_cell <- function(x, to, ...) {
  hilo_to_hex_rs(vctrs::field(x, "hi"), vctrs::field(x, "lo"))
}

# --- pillar formatting for tibbles ---

#' @exportS3Method pillar::pillar_shaft
#' @noRd
#' @keywords internal
pillar_shaft.a5_cell <- function(x, ...) {
  out <- format(x)
  pillar::new_pillar_shaft_simple(out, align = "left")
}
