# Base R compatibility for a5_cell.
#
# a5_cell is a vctrs record: underneath it is a list of eight raw vectors, one
# per byte of the 64-bit id. Base functions that inspect that structure
# directly need help; these methods cover the ones ordinary code hits.

#' @exportS3Method base::mtfrm
mtfrm.a5_cell <- function(x) {
  # match(), %in% and friends call mtfrm() on objects. The default converts
  # to character (a hex string per cell), which costs about 25 ms per 100k
  # cells at each end of the match. Pack the eight bytes into a complex
  # number instead: each half is an integer below 2^32, exactly
  # representable as a double, so the key is exact and hashing is native.
  d <- unclass(x)
  b <- function(f) as.double(d[[f]])
  hi <- ((b("b8") * 256 + b("b7")) * 256 + b("b6")) * 256 + b("b5")
  lo <- ((b("b4") * 256 + b("b3")) * 256 + b("b2")) * 256 + b("b1")
  complex(real = hi, imaginary = lo)
}

#' @export
`[<-.a5_cell` <- function(x, i, value) {
  # vctrs refuses to assign past the end. Base R grows the vector, padding
  # with NA, and base::rbind() on data frames relies on that. Grow here,
  # then let vctrs do the (still type-checked) assignment.
  if (!missing(i) && is.numeric(i) && length(i) > 0L) {
    m <- max(i, na.rm = TRUE)
    if (m > length(x)) {
      x <- vctrs::vec_c(x, na_a5_cell(m - length(x)))
    }
  }
  NextMethod()
}

#' @export
`length<-.a5_cell` <- function(x, value) {
  n <- length(x)
  if (value <= n) {
    return(vctrs::vec_slice(x, seq_len(value)))
  }
  vctrs::vec_c(x, na_a5_cell(value - n))
}

na_a5_cell <- function(n) {
  vctrs::vec_rep(a5_cell(NA_character_), n)
}
