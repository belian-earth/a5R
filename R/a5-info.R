#' a5R build and session information
#'
#' Returns the versions behind a5R and its current settings, as a named list
#' that prints as a summary. The same summary, on one line, is shown when the
#' package is attached with [library()].
#'
#' The `index` element names the A5 cell index that a5R's ids belong to. Ids
#' from different index versions look alike, and nothing in an id says which
#' version wrote it (see [a5_migrate()]), so record `index` with stored
#' cells and check it when reading them back. With Arrow and Parquet,
#' [a5_to_arrow_table()] stores it in the schema metadata under the key
#' `"a5:index_version"`, and [a5_from_arrow_table()] checks it.
#'
#' @returns A list of class `a5_info` with elements:
#'   - `version`: the a5R package version, a character scalar.
#'   - `crate`: the version of the bundled a5 Rust crate.
#'   - `index`: the A5 cell index version of a5R's ids, `"1.0"`.
#'   - `threads`: the current thread count (see [a5_set_threads()]).
#'   - `c_api`: the version of the C API (see [a5_c_api]).
#' @export
#' @examples
#' a5_info()
#' a5_info()$index
a5_info <- function() {
  structure(
    list(
      version = as.character(utils::packageVersion("a5R")),
      crate = a5_crate_version_rs(),
      index = A5_INDEX_VERSION,
      threads = a5_get_threads(),
      c_api = 1L
    ),
    class = "a5_info"
  )
}

# The A5 cell index of a5R's ids.
A5_INDEX_VERSION <- "1.0"

#' @export
print.a5_info <- function(x, ...) {
  cli::cli_rule(left = "a5R {x$version}")
  cli::cli_dl(c(
    "a5 crate" = x$crate,
    "A5 index" = x$index,
    "Threads" = as.character(x$threads),
    "C API" = as.character(x$c_api)
  ))
  invisible(x)
}

#' One-line summary for the attach message
#' @noRd
a5_info_line <- function(x = a5_info()) {
  cli::format_inline(
    "a5R {x$version} {cli::symbol$bullet} a5 crate {x$crate} ",
    "{cli::symbol$bullet} A5 index {x$index} {cli::symbol$bullet} ",
    "{x$threads} thread{?s}"
  )
}
