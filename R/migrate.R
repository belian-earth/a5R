#' Migrate cell ids from the pre-1.0 index
#'
#' Converts cell ids written by a5R before 1.0 (the a5 Rust crate 0.10 and
#' earlier, the "v0" index) to the current, permanent index. A5 1.0 threads
#' its space-filling curve through the cells differently, so cells keep their
#' shape and position but get new ids. The conversion is a cheap bit
#' operation; there is no need to re-index data from its coordinates. The
#' exception is resolution 1, whose 60 cells changed from triangles to
#' pentagons: each migrated resolution-1 id is the new cell containing the old
#' cell's centre.
#'
#' A v0 id is still a valid cell in the current index, but in a different
#' place, and nothing in the id records which version wrote it. Migrate stored
#' ids exactly once, as soon as they are read: migrating current ids, or
#' migrating twice, gives wrong cells without any error.
#'
#' Upstream will retire this conversion in a future version.
#'
#' @param cell An [a5_cell] vector of ids in the v0 index.
#' @returns An [a5_cell] vector of the same cells in the current index, the
#'   same length as `cell`. `NA` where `cell` is `NA`.
#'
#' @seealso [a5_cell_from_arrow()] to read stored ids.
#' @export
#' @examples
#' # A resolution-8 cell id from a5R 0.6.0
#' v0 <- a5_cell("59c4780000000000")
#' a5_migrate(v0)
a5_migrate <- function(cell) {
  cell <- as_a5_cell(cell)
  cells_from_rs(a5_migrate_rs(cell_data(cell)))
}
