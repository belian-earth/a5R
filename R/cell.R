#' A5 Cell Index Vector
#'
#' A vctrs-based vector type representing A5 cell indices. Cell IDs are
#' stored as hex-encoded character strings internally. The `a5_cell` type
#' provides type safety, pretty-printing, and integration with the vctrs
#' framework.
#'
#' @param x A character vector of hex-encoded A5 cell IDs, or an object
#'   coercible to one.
#' @returns An `a5_cell` vector.
#'
#' @export
#' @examples
#' cells <- a5_cell(c("0800000000000006", "0800000000000016"))
#' cells
a5_cell <- function(x = character()) {
  x <- vctrs::vec_cast(x, character())
  new_a5_cell(x)
}

new_a5_cell <- function(x = character()) {
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
  vctrs::vec_data(x)
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
vec_cast.a5_cell.character <- function(x, to, ...) new_a5_cell(x)

#' @export
#' @noRd
#' @keywords internal
vec_cast.character.a5_cell <- function(x, to, ...) vctrs::vec_data(x)

# --- pillar formatting for tibbles ---

#' @exportS3Method pillar::pillar_shaft
#' @noRd
#' @keywords internal
pillar_shaft.a5_cell <- function(x, ...) {
  out <- format(x)
  pillar::new_pillar_shaft_simple(out, align = "left")
}
