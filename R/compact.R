#' Compact and uncompact sets of cells
#'
#' `a5_compact()` stores a set of cells as an [a5_covering]: every complete
#' group of siblings is replaced by its parent, repeatedly, giving the fewest
#' cells for the same set, and the covering records the resolution the set
#' stands for. `a5_uncompact()` expands coverings back to their cells at that
#' resolution, or at a finer one. Uncompacting a compacted set returns the
#' original cells, sorted in curve order and without duplicates.
#'
#' Both work on the index hierarchy (see [a5_hierarchy]), so the coverage they
#' preserve is the set of index descendants, not a geometric area.
#'
#' @param cell An [a5_cell] vector. `NA` cells are skipped.
#' @param x An [a5_covering] vector, or an [a5_cell] vector treated as one
#'   covering (see `as_a5_covering()`).
#' @param resolution Integer scalar resolution. For `a5_compact()`, the
#'   resolution the covering stands for: by default that of the finest cell,
#'   and never finer than it. For `a5_uncompact()`, the resolution to expand
#'   to: by default each covering's own, and never coarser than it.
#' @param simplify Logical scalar. If `TRUE` (default), return one flat
#'   [a5_cell] vector with the cells of every covering concatenated in input
#'   order. If `FALSE`, return an [a5_cell_list] with one element per
#'   covering, suitable for a list column.
#' @returns `a5_compact()`: an [a5_covering] of length one.
#'   `a5_uncompact()`: an [a5_cell] vector, or an [a5_cell_list] when
#'   `simplify = FALSE`, with each covering's cells in curve order. A missing
#'   covering contributes no cells (an empty element in the list form).
#'
#' @section Memory:
#' A covering can stand for far more cells than it stores: a country at
#' resolution 18 is about a billion cells, stored as a few hundred thousand.
#' `a5_uncompact()` refuses to build more than `.Machine$integer.max` cells;
#' check with [a5_covering] printing first, and prefer the covering functions
#' that work on compacted sets.
#'
#' @seealso [a5_covering], [a5_polygon_to_cells()] and [a5_grid_disk()],
#'   which return coverings.
#' @name a5_compaction
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' children <- a5_cell_to_children(cell, resolution = 7)
#' covering <- a5_compact(children) # stored as the parent
#' covering
#' a5_uncompact(covering)           # the 16 children again
#'
#' # expand to a finer resolution
#' a5_uncompact(a5_compact(cell), resolution = 7)
#'
#' # one covering per element, kept apart with simplify = FALSE
#' disks <- a5_grid_disk(a5_cell_to_children(cell), k = 1)
#' a5_uncompact(disks, simplify = FALSE)
NULL

#' @rdname a5_compaction
#' @export
a5_compact <- function(cell, resolution = NULL) {
  cell <- as_a5_cell(cell)
  resolution <- check_optional_resolution(resolution)
  coverings_from_rs(from_caller(a5_compact_rs(cell_data(cell), resolution), call = rlang::current_env()))
}

#' @rdname a5_compaction
#' @export
a5_uncompact <- function(x, resolution = NULL, simplify = TRUE) {
  if (!is_a5_covering(x)) {
    x <- as_a5_covering(as_a5_cell(x))
  }
  resolution <- check_optional_resolution(resolution)
  check_flag(simplify)
  s <- a5_covering_summary_rs(x)
  total <- if (is.null(resolution)) {
    sum(s$count, na.rm = TRUE)
  } else {
    # 5 children from resolution 0 to 1, then 4 per step
    d <- pmax(resolution - s$resolution, 0L)
    sum(s$count * 4^d * ifelse(s$resolution == 0L & d > 0L, 5 / 4, 1), na.rm = TRUE)
  }
  if (total > .Machine$integer.max) {
    a5_abort("size", c(
      "Uncompacting would build {format(total, big.mark = ',', scientific = FALSE)} cells.",
      "i" = "Work with the covering instead, or uncompact a smaller area."
    ))
  }
  one_to_many(from_caller(a5_uncompact_rs(x, resolution, simplify), call = rlang::current_env()), simplify)
}
