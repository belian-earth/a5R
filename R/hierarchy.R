#' Get the resolution of A5 cell indices
#'
#' Extracts the resolution level (0--30) encoded in each cell index.
#'
#' @param cell An [a5_cell] vector.
#' @returns An integer vector of resolutions.
#'
#' @seealso [a5_cell_to_parent()], [a5_cell_to_children()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
#' a5_get_resolution(cell)
a5_get_resolution <- function(cell) {
  cell <- as_a5_cell(cell)
  a5_get_resolution_rs(cell_data(cell))
}

#' Navigate to parent cell(s)
#'
#' Returns the parent cell of each input cell. By default returns the
#' immediate parent (one resolution coarser). Optionally target a specific
#' coarser resolution.
#'
#' @param cell An [a5_cell] vector.
#' @param resolution Integer scalar target parent resolution, or `NULL` for
#'   the immediate parent.
#' @returns An [a5_cell] vector of parent cells.
#'
#' @seealso [a5_cell_to_children()], [a5_get_resolution()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
#' a5_cell_to_parent(cell)
#' a5_cell_to_parent(cell, resolution = 5)
a5_cell_to_parent <- function(cell, resolution = NULL) {
  cell <- as_a5_cell(cell)
  if (!is.null(resolution)) {
    resolution <- vctrs::vec_cast(resolution, integer())
    check_resolution(resolution)
    check_size1(resolution)
  }
  cells_from_rs(a5_cell_to_parent_rs(cell_data(cell), resolution))
}

#' The i-th child of each cell
#'
#' Returns one descendant of each cell at a finer resolution without
#' enumerating the others: the `i`-th element of what
#' [a5_cell_to_children()] would return. Useful for random draws from large
#' cells, where building the full child list to pick one element is wasteful.
#'
#' @param cell An [a5_cell] vector.
#' @param resolution Integer scalar target resolution, at or finer than every
#'   cell's own resolution.
#' @param i Integer vector of 1-based child positions, recycled against
#'   `cell`. Must lie within `1:a5_get_num_children(res, resolution)` for each
#'   cell's resolution `res`; out of range is an error.
#' @returns An [a5_cell] vector the same length as `cell`. `NA` where `cell`
#'   or `i` is `NA`.
#'
#' @seealso [a5_cell_to_children()], [a5_get_num_children()]
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_child(cell, resolution = 7, i = 1:16)
#' identical(a5_cell_child(cell, 7, 1:16), a5_cell_to_children(cell, 7))
a5_cell_child <- function(cell, resolution, i) {
  cell <- as_a5_cell(cell)
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_size1(resolution)
  args <- vctrs::vec_recycle_common(cell = cell, i = vctrs::vec_cast(i, integer()))
  cells_from_rs(a5_cell_child_rs(cell_data(args$cell), resolution, args$i))
}

#' Range of descendant cell ids
#'
#' Returns the smallest and largest descendant of each cell at a finer
#' resolution, without enumerating the descendants. Because the A5 index
#' encodes position along a Hilbert curve with a cell's descendants sharing
#' its leading bits, the descendants of a cell at any resolution up to 29
#' occupy a contiguous range of ids among all cells at that resolution: every
#' cell at `resolution` whose id lies between `lo` and `hi` inclusive is a
#' descendant, and no descendant lies outside. This makes `BETWEEN lo AND hi`
#' an exact filter on a store of `resolution` cells sorted by id. Not every
#' integer in the range is a valid cell, and cells of other resolutions may
#' fall inside it. At resolution 30 the encoding varies by dodecahedron
#' face, so the contiguity guarantee does not hold across faces there.
#'
#' @param cell An [a5_cell] vector.
#' @param resolution Integer scalar target resolution, at or finer than every
#'   cell's own resolution.
#' @returns A data frame with [a5_cell] columns `lo` and `hi`, one row per
#'   input cell. `NA` where `cell` is `NA`.
#'
#' @seealso [a5_cell_to_children()], [a5_cell_to_arrow()] for exact 64-bit
#'   ids to pass to SQL.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' rng <- a5_cell_children_range(cell, resolution = 8)
#' children <- vctrs::vec_sort(a5_cell_to_children(cell, resolution = 8))
#' identical(rng$lo, children[1])
#' identical(rng$hi, children[length(children)])
a5_cell_children_range <- function(cell, resolution) {
  cell <- as_a5_cell(cell)
  resolution <- vctrs::vec_cast(resolution, integer())
  check_resolution(resolution)
  check_size1(resolution)
  rs <- a5_cell_children_range_rs(cell_data(cell), resolution)
  vctrs::new_data_frame(list(lo = cells_from_rs(rs$lo), hi = cells_from_rs(rs$hi)))
}

#' Get child cells
#'
#' Returns the child cells of each input cell. By default returns the 4
#' immediate children (one resolution finer). Optionally target a specific
#' finer resolution.
#'
#' @param cell An [a5_cell] vector.
#' @param resolution Integer scalar target child resolution, or `NULL` for
#'   immediate children.
#' @param simplify Logical scalar. If `TRUE` (default), return one flat
#'   [a5_cell] vector with the children of every input concatenated in input
#'   order; which child came from which parent is not recorded. If `FALSE`,
#'   return a [vctrs::list_of()] of [a5_cell] vectors with one element per
#'   input, suitable for a list column.
#' @returns An [a5_cell] vector, or a list of them when `simplify = FALSE`.
#'   An `NA` input contributes no cells (an empty element in the list form).
#'
#' @seealso [a5_cell_to_parent()], [a5_get_resolution()], [a5_cell_child()]
#'   for one child at a time, [a5_cell_children_range()] for the id range of
#'   all descendants.
#' @export
#' @examples
#' cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#' a5_cell_to_children(cell)
#'
#' cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
#' a5_cell_to_children(cells, resolution = 7)                  # 32 cells
#' a5_cell_to_children(cells, resolution = 7, simplify = FALSE) # list of 2
a5_cell_to_children <- function(cell, resolution = NULL, simplify = TRUE) {
  cell <- as_a5_cell(cell)
  if (!is.null(resolution)) {
    resolution <- vctrs::vec_cast(resolution, integer())
    check_resolution(resolution)
    check_size1(resolution)
  }
  check_flag(simplify)
  one_to_many(a5_cell_to_children_rs(cell_data(cell), resolution), simplify)
}
