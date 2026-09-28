#' Compact and uncompact sets of cells
#'
#' `a5_compact()` replaces every complete set of siblings with their common
#' parent, repeatedly, giving the fewest cells that cover the same set.
#' `a5_uncompact()` expands each cell to its descendants at a target
#' resolution. Uncompacting a compacted set to the original resolution
#' returns the original cells.
#'
#' Both work on the index hierarchy (see [a5_hierarchy]), so the coverage they
#' preserve is the set of index descendants, not a geometric area.
#'
#' @param cells An [a5_cell] vector.
#' @param resolution Integer scalar target resolution (0--30), at or finer
#'   than every cell's own resolution.
#' @returns An [a5_cell] vector: mixed resolutions for `a5_compact()`, all at
#'   `resolution` for `a5_uncompact()`.
#'
#' @seealso [a5_polygon_to_cells()] and [a5_grid_disk()], which return
#'   compacted sets.
#' @name a5_compaction
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' children <- a5_cell_to_children(cell, resolution = 7)
#' a5_compact(children) # back to the parent
#' a5_uncompact(cell, resolution = 7)
#'
#' # the round trip restores the original cells
#' identical(vctrs::vec_sort(a5_uncompact(a5_compact(children), 7)),
#'           vctrs::vec_sort(children))
NULL

#' @rdname a5_compaction
#' @export
a5_compact <- function(cells) {
  cells <- as_a5_cell(cells)
  cells_from_rs(a5_compact_rs(cell_data(cells)))
}

#' @rdname a5_compaction
#' @export
a5_uncompact <- function(cells, resolution) {
  cells <- as_a5_cell(cells)
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_size1(resolution)
  cells_from_rs(a5_uncompact_rs(cell_data(cells), resolution))
}
