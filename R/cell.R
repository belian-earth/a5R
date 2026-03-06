#' A5 Cell Index Vector
#'
#' Create, test, and coerce A5 cell index vectors. Cells are stored as
#' a list of raw(8) blobs (little-endian u64).
#'
#' @param x A character vector of hex-encoded A5 cell IDs, or an object
#'   coercible to one.
#' @returns An `a5_cell` vector (`a5_cell`, `as_a5_cell`), a logical
#'   scalar (`is_a5_cell`), or a logical vector (`a5_is_cell`).
#'
#' @export
#' @examples
#' cells <- a5_cell(c("0800000000000006", "0800000000000016"))
#' cells
a5_cell <- function(x = character()) {
  x <- vctrs::vec_cast(x, character())
  new_a5_cell(hex_to_blob_rs(x))
}

new_a5_cell <- function(x = list()) {
  vctrs::new_vctr(x, class = "a5_cell")
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
#' a5_is_cell(c("0800000000000006", "not_a_cell", NA))
a5_is_cell <- function(x) {
  if (is_a5_cell(x)) {
    a5_is_valid_cell_rs(vctrs::vec_data(x))
  } else {
    x <- vctrs::vec_cast(x, character())
    a5_is_valid_hex_rs(x)
  }
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
  out <- blob_to_hex_rs(vctrs::vec_data(x))
  # Convert NA_character_ from blob_to_hex_rs to NA for proper display
  out[is.na(out)] <- NA
  out
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
vec_cast.a5_cell.character <- function(x, to, ...) new_a5_cell(hex_to_blob_rs(x))

#' @export
#' @noRd
#' @keywords internal
vec_cast.character.a5_cell <- function(x, to, ...) blob_to_hex_rs(vctrs::vec_data(x))

# --- pillar formatting for tibbles ---

#' @exportS3Method pillar::pillar_shaft
#' @noRd
#' @keywords internal
pillar_shaft.a5_cell <- function(x, ...) {
  out <- format(x)
  pillar::new_pillar_shaft_simple(out, align = "left")
}
