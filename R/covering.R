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
#' Use coverings through a5R functions where one fits. The stored cells are
#' index parents (see [a5_hierarchy]): their outlines do not nest
#' geometrically, so drawing them shows overlaps and gaps. Uncompact a
#' covering before plotting or joining it to data keyed by cell. For index
#' range queries, [a5_covering_stored()] returns the stored cells.
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
#'   [a5_cell_list] (one covering per element), or a list of [a5_cell]
#'   vectors or of raw vectors of little-endian 64-bit values, as stored by
#'   other A5 libraries. `NULL` list elements are missing coverings. For `a5_covering_resolution()` and
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
#' kids <- a5_cell_to_children(cell, child_resolution = 10)
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
  coverings_from_rs(from_caller(a5_compact_each_rs(lapply(x, cell_data), resolution), call = rlang::current_env()))
}

#' @rdname a5_covering
#' @export
as_a5_covering.list <- function(x, resolution = NULL, ...) {
  is_null <- vapply(x, is.null, logical(1))
  is_cell <- vapply(x, is_a5_cell, logical(1))
  # all-NULL input takes the raw path below, where NULL is missing
  if (any(is_cell) && all(is_null | is_cell)) {
    out <- as_a5_covering(as_a5_cell_list(x), resolution = resolution)
    out[is_null] <- NA
    return(out)
  }
  is_raw <- vapply(x, function(el) is.null(el) || is.raw(el), logical(1))
  if (!all(is_raw)) {
    a5_abort("cell",
      "{.arg x} must be a list of {.cls a5_cell} vectors or of raw vectors."
    )
  }
  odd <- which(lengths(x) %% 8L != 0L)
  if (length(odd) > 0L) {
    a5_abort("cell",
      "Raw element {odd[1]} of {.arg x} has {length(x[[odd[1]]])} bytes, not a multiple of 8."
    )
  }
  resolution <- check_optional_resolution(resolution)
  coverings_from_rs(from_caller(a5_covering_normalise_rs(unname(x), resolution), call = rlang::current_env()))
}

#' @export
as_a5_covering.default <- function(x, ...) {
  a5_abort("cell", "Can't convert {.obj_type_friendly {x}} to {.cls a5_covering}.")
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

#' Stored cells of a covering
#'
#' Returns the cells a covering stores: its compacted cells, which have
#' mixed resolutions, in curve order and without the compaction marker. Use
#' them for index range queries. Each stored cell's descendants at the
#' covering's resolution form one contiguous id range, given by
#' [a5_cell_children_range()], so a covering is the union of those ranges.
#'
#' The stored cells are index parents, not geometric ones: their outlines do
#' not nest, so do not draw them or use them as an area. Use
#' [a5_uncompact()] for the cells a covering stands for.
#'
#' @param x An [a5_covering] vector, or anything [as_a5_covering()] accepts.
#' @param simplify Logical scalar. If `TRUE` (default), return one flat
#'   [a5_cell] vector with the stored cells of every covering in turn. If
#'   `FALSE`, return an [a5_cell_list] with one element per covering; a
#'   missing covering gives an empty element.
#' @returns An [a5_cell] vector, or an [a5_cell_list] if `simplify = FALSE`.
#'
#' @seealso [a5_uncompact()] for the cells at the covering's resolution,
#'   [a5_covering_resolution()], [a5_cell_children_range()].
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
#' disk <- a5_grid_disk(cell, k = 3)
#' stored <- a5_covering_stored(disk)
#' a5_get_resolution(stored)
#'
#' # one id range per stored cell, at the covering's resolution
#' a5_cell_children_range(stored, child_resolution = a5_covering_resolution(disk))
a5_covering_stored <- function(x, simplify = TRUE) {
  x <- as_a5_covering(x)
  check_flag(simplify)
  one_to_many(a5_covering_stored_rs(x, simplify), simplify)
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
  check_scalar_resolution(resolution, call = call)
}

# --- methods ------------------------------------------------------------------

#' @export
format.a5_covering <- function(x, ...) {
  a5_covering_format_rs(x)
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
