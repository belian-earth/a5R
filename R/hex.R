#' Convert hex string to A5 cell
#'
#' Convenience wrapper to construct an [a5_cell] from a hex string.
#'
#' @param hex Character vector of hex-encoded cell IDs.
#' @returns An [a5_cell] vector.
#'
#' @export
#' @examples
#' a5_hex_to_cell("0800000000000006")
a5_hex_to_cell <- function(hex) {
  hex <- vctrs::vec_cast(hex, character())
  new_a5_cell(hex)
}

#' Test if values are valid A5 cell indices
#'
#' Checks whether each element is a syntactically valid hex-encoded A5 cell
#' ID.
#'
#' @param x An [a5_cell] vector or character vector of hex strings.
#' @returns A logical vector.
#'
#' @export
#' @examples
#' a5_is_cell(c("0800000000000006", "not_a_cell", NA))
a5_is_cell <- function(x) {
  if (is_a5_cell(x)) {
    x <- vctrs::vec_data(x)
  } else {
    x <- vctrs::vec_cast(x, character())
  }
  a5_is_valid_cell_rs(x)
}
