#' A5 covering vectors
#'
#' A covering is a set of A5 cells at one resolution, standing for an area of
#' the globe, possibly in disjoint parts: the cells of a polygon, a disk or a
#' cap. It is stored compacted. Complete groups of sibling cells are replaced
#' by their parent, so the stored cells have mixed resolutions, and a
#' trailing *compaction marker* records the resolution they stand for. An
#' `a5_covering` vector holds one covering per element, so it fits in a data
#' frame column, with one covering per feature or per centre cell.
#'
#' [a5_polygon_to_cells()], [a5_grid_disk()], [a5_spherical_cap()] and
#' [a5_compact()] return coverings. `as_a5_covering()` builds them from cells
#' or from raw 64-bit values, sorting and compacting them as needed.
#' `a5_covering_resolution()` returns the resolution each covering stands
#' for, and [a5_uncompact()] expands coverings to their cells.
#'
#' @section Working with coverings:
#' Use coverings through a5R functions rather than by reading the stored
#' cells. The stored cells are index parents (see [a5_hierarchy]): their
#' outlines do not nest geometrically, so drawing them shows overlaps and
#' gaps. Uncompact a covering before plotting or joining it to data keyed by
#' cell.
#'
#' `length()` counts coverings, not cells. `x[i]` and `x[[i]]` both return
#' coverings, and `c()` concatenates them. Two coverings of the same cells
#' compare equal with `==`, because a5R always stores a covering in the same
#' sorted, compacted form. A missing covering is `NA`, for example the disk
#' around an `NA` cell; an empty covering (no cells) is not missing.
#'
#' Coverings are stored with the compaction marker, as in the other A5
#' libraries, so [a5_covering_to_arrow()] writes them to a `list<uint64>`
#' column that DuckDB, Python and JavaScript read without losing the
#' resolution.
#'
#' @param x For `as_a5_covering()`: an [a5_cell] vector (one covering), an
#'   [a5_cell_list] (one covering per element), or a list of raw vectors of
#'   little-endian 64-bit values, as stored by other A5 libraries (`NULL`
#'   elements are missing). For `a5_covering_resolution()` and
#'   `is_a5_covering()`: any object.
#' @param resolution Integer scalar resolution the coverings stand for, or
#'   `NULL` (the default) for the resolution of each input's finest cell. No
#'   cell may be finer than `resolution`. Ignored for raw input that carries
#'   a compaction marker.
#' @param ... Unused.
#' @returns `as_a5_covering()`: an `a5_covering` vector.
#'   `a5_covering_resolution()`: an integer vector, `NA` for a missing
#'   covering and -1 for an empty one without a recorded resolution.
#'   `is_a5_covering()`: a logical scalar.
#'
#' @seealso [a5_uncompact()], [a5_is_valid()], [a5_covering_to_arrow()].
#' @name a5_covering
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' disk <- a5_grid_disk(cell, k = 3)
#' disk
#' a5_covering_resolution(disk)
#'
#' # from cells: complete sibling groups are stored as their parent
#' kids <- a5_cell_to_children(cell, resolution = 10)
#' as_a5_covering(kids)
#' as_a5_covering(kids[-1])
NULL

#' @rdname a5_covering
#' @export
as_a5_covering <- function(x, ...) {
  UseMethod("as_a5_covering")
}

#' @rdname a5_covering
#' @export
as_a5_covering.a5_covering <- function(x, ...) {
  x
}

#' @rdname a5_covering
#' @export
as_a5_covering.a5_cell <- function(x, resolution = NULL, ...) {
  a5_compact(x, resolution = resolution)
}

#' @rdname a5_covering
#' @export
as_a5_covering.a5_cell_list <- function(x, resolution = NULL, ...) {
  resolution <- check_optional_resolution(resolution)
  coverings_from_rs(a5_compact_each_rs(lapply(x, cell_data), resolution))
}

#' @rdname a5_covering
#' @export
as_a5_covering.list <- function(x, resolution = NULL, ...) {
  if (length(x) > 0L && all(vapply(x, function(el) is.null(el) || is_a5_cell(el), logical(1)))) {
    return(as_a5_covering(as_a5_cell_list(x), resolution = resolution))
  }
  is_raw <- vapply(x, function(el) is.null(el) || is.raw(el), logical(1))
  if (!all(is_raw)) {
    cli::cli_abort(
      "{.arg x} must be a list of {.cls a5_cell} vectors or of raw vectors."
    )
  }
  odd <- which(lengths(x) %% 8L != 0L)
  if (length(odd) > 0L) {
    cli::cli_abort(
      "Raw element {odd[1]} of {.arg x} has {length(x[[odd[1]]])} bytes, not a multiple of 8."
    )
  }
  resolution <- check_optional_resolution(resolution)
  coverings_from_rs(a5_covering_normalise_rs(unname(x), resolution))
}

#' @export
as_a5_covering.default <- function(x, ...) {
  cli::cli_abort("Can't convert {.obj_type_friendly {x}} to {.cls a5_covering}.")
}

#' @rdname a5_covering
#' @export
is_a5_covering <- function(x) {
  inherits(x, "a5_covering")
}

#' @rdname a5_covering
#' @export
a5_covering_resolution <- function(x) {
  x <- as_a5_covering(x)
  a5_covering_summary_rs(x)$resolution
}

#' Wrap a Rust-built list of coverings
#' @noRd
coverings_from_rs <- function(x) {
  structure(x, class = c("a5_covering", "vctrs_vctr", "list"))
}

#' @noRd
new_a5_covering <- function(x = list()) {
  coverings_from_rs(x)
}

#' Validate an optional scalar resolution
#' @noRd
check_optional_resolution <- function(resolution, call = rlang::caller_env()) {
  if (is.null(resolution)) {
    return(NULL)
  }
  resolution <- vctrs::vec_cast(resolution, integer(), call = call)
  check_resolution(resolution, call = call)
  check_size1(resolution, call = call)
  resolution
}

# --- methods ------------------------------------------------------------------

#' @export
format.a5_covering <- function(x, ...) {
  s <- a5_covering_summary_rs(x)
  count <- format(s$count, big.mark = ",", scientific = FALSE, trim = TRUE)
  stored <- format(s$stored, big.mark = ",", trim = TRUE)
  out <- sprintf(
    "res %d: %s %s (%s stored)",
    s$resolution, count, ifelse(s$count == 1, "cell", "cells"), stored
  )
  out[s$count %in% 0] <- sprintf("res %d: empty", s$resolution[s$count %in% 0])
  out[s$resolution %in% -1L] <- ifelse(s$count[s$resolution %in% -1L] %in% 0, "empty", "world")
  out[is.na(s$resolution)] <- NA_character_
  out
}

#' @export
is.na.a5_covering <- function(x) {
  vapply(unclass(x), is.null, logical(1), USE.NAMES = FALSE)
}

#' @export
`[[.a5_covering` <- function(x, i) {
  x[i]
}

#' @exportS3Method vctrs::vec_ptype_abbr
vec_ptype_abbr.a5_covering <- function(x, ...) "a5_covering"

#' @exportS3Method vctrs::vec_ptype_full
vec_ptype_full.a5_covering <- function(x, ...) "a5_covering"

#' @export
vec_ptype2.a5_covering.a5_covering <- function(x, y, ...) new_a5_covering()

#' @export
vec_cast.a5_covering.a5_covering <- function(x, to, ...) x

#' @exportS3Method pillar::pillar_shaft
pillar_shaft.a5_covering <- function(x, ...) {
  pillar::new_pillar_shaft_simple(format(x), align = "left", na = pillar::style_na("NA"))
}
