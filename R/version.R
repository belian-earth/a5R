#' A5 index and library versions
#'
#' `a5_index_version()` names the A5 cell index that a5R's ids belong to.
#' Ids from different index versions look alike, and nothing in an id says
#' which version wrote it (see [a5_migrate()]), so record this value with
#' stored cells and check it when reading them back. With Arrow and Parquet,
#' store it in the schema metadata under the key `"a5:index_version"`, as in
#' the example.
#'
#' `a5_crate_version()` gives the version of the bundled a5 Rust crate, for
#' bug reports and for packages that must match a5R's build.
#'
#' @returns A character scalar.
#' @seealso [a5_migrate()] for ids from the pre-1.0 index.
#' @export
#' @examples
#' a5_index_version()
#' a5_crate_version()
#'
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
#' tbl <- arrow::arrow_table(cell = a5_cell_to_arrow(cells))
#' tbl$metadata[["a5:index_version"]] <- a5_index_version()
#' tbl$metadata[["a5:index_version"]] == a5_index_version()
a5_index_version <- function() {
  "1.0"
}

#' @rdname a5_index_version
#' @export
a5_crate_version <- function() {
  a5_crate_version_rs()
}
