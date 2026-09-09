#!/usr/bin/env Rscript
# Compare a5R releases against each other (and h3o) on the per-call operations.
#
# Parameters mirror the Python micro-benchmark written by Takashi (a5
# contributor): a Tokyo point, a5 resolution 12 / H3 resolution 8, grid_disk
# k = 10, and a 7-vertex Hiroshima polygon with centre containment.
#
# Each a5R version is benchmarked in its own R subprocess (callr) because two
# versions of the same package cannot be loaded into one session. Archived
# versions are installed on demand into benchmarks/lib/a5R-<ver>.
#
# Usage:
#   Rscript benchmarks/bench_versions.R                 # 0.5.0 vs installed
#   Rscript benchmarks/bench_versions.R 0.4.0 0.5.0 installed
#   Rscript benchmarks/bench_versions.R installed lib/a5R-dev
#
# "installed" means whichever a5R is on the default library path; an existing
# directory is used as an R library (e.g. a development build made with
# `R CMD INSTALL --library=benchmarks/lib/a5R-dev .`). Writes
# results_versions.json, which summarise.R merges into RESULTS.md.

suppressPackageStartupMessages({
  library(callr)
  library(jsonlite)
})

bench_dir <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
lib_root <- file.path(bench_dir, "lib")
dir.create(lib_root, showWarnings = FALSE)

versions <- commandArgs(trailingOnly = TRUE)
if (length(versions) == 0) {
  versions <- c("0.5.0", "installed")
  dev_lib <- file.path(lib_root, "a5R-dev")
  if (dir.exists(dev_lib)) versions <- c(versions, dev_lib)
}

# -- Parameters ---------------------------------------------------------------
coord <- c(139.70033506856208, 35.690624903733436)
a5_resolution <- 12L
h3_resolution <- 8L
grid_disk_k <- 10L
percall_n <- c(lonlat_to_cell = 1000L, grid_disk = 200L, polygon_to_cells = 200L)

polygon <- matrix(c(
  132.3555094, 34.3465028, 132.4945511, 34.3288744, 132.5876105, 34.4237528,
  132.6023905, 34.5338573, 132.4075132, 34.5600083, 132.2920101, 34.5022848,
  132.2575233, 34.4065923, 132.3555094, 34.3465028
), ncol = 2, byrow = TRUE)
polygon_wkt <- sprintf(
  "POLYGON ((%s))",
  paste(sprintf("%.7f %.7f", polygon[, 1], polygon[, 2]), collapse = ", ")
)

# -- Workers ------------------------------------------------------------------
# Self-contained: callr serialises the function, so everything comes in as
# arguments and every package is attached inside.

bench_a5r <- function(coord, a5_resolution, k, polygon_wkt, percall_n) {
  suppressPackageStartupMessages({
    library(a5R)
    library(bench)
  })
  a5_set_threads(1L)
  impl <- sprintf("a5R %s", packageVersion("a5R"))
  if (grepl("9000$", impl)) impl <- paste(impl, "(dev)")
  cell <- a5_lonlat_to_cell(coord[1], coord[2], resolution = a5_resolution)
  poly <- wk::wkt(polygon_wkt)

  one <- function(op, expr) {
    # The expression must reach bench::mark unevaluated, so splice its AST in.
    call <- bquote(bench::mark(.(substitute(expr)), iterations = .(percall_n[[op]]),
                               check = FALSE, memory = FALSE, filter_gc = FALSE))
    b <- eval(call, parent.frame())
    data.frame(impl = impl, lang = "R", operation = op,
               median_us = as.numeric(b$median) * 1e6, stringsAsFactors = FALSE)
  }
  pc <- rbind(
    one("lonlat_to_cell", a5_lonlat_to_cell(coord[1], coord[2], resolution = a5_resolution)),
    one("grid_disk", a5_grid_disk(cell, k)),
    one("polygon_to_cells", a5_polygon_to_cells(poly, a5_resolution))
  )
  pc$n_cells <- c(1L, length(a5_grid_disk(cell, k)), length(a5_polygon_to_cells(poly, a5_resolution)))
  list(percall = pc, ref = setNames(list(list(
    cell = as.character(cell), grid_disk_n = pc$n_cells[2], polygon_n = pc$n_cells[3]
  )), impl))
}

bench_h3o <- function(coord, h3_resolution, k, polygon, percall_n) {
  suppressPackageStartupMessages({
    library(h3o)
    library(bench)
  })
  impl <- sprintf("h3o %s", packageVersion("h3o"))
  cell <- h3_from_xy(coord[1], coord[2], h3_resolution)
  sfc <- sf::st_sfc(sf::st_polygon(list(polygon)), crs = 4326)

  one <- function(op, expr) {
    # The expression must reach bench::mark unevaluated, so splice its AST in.
    call <- bquote(bench::mark(.(substitute(expr)), iterations = .(percall_n[[op]]),
                               check = FALSE, memory = FALSE, filter_gc = FALSE))
    b <- eval(call, parent.frame())
    data.frame(impl = impl, lang = "R", operation = op,
               median_us = as.numeric(b$median) * 1e6, stringsAsFactors = FALSE)
  }
  # "centroid" matches a5's centre containment and h3-py's default.
  pc <- rbind(
    one("lonlat_to_cell", h3_from_xy(coord[1], coord[2], h3_resolution)),
    one("grid_disk", grid_disk(cell, k)),
    one("polygon_to_cells", sfc_to_cells(sfc, h3_resolution, containment = "centroid"))
  )
  pc$n_cells <- c(1L, length(grid_disk(cell, k)[[1]]),
                  length(sfc_to_cells(sfc, h3_resolution, containment = "centroid")[[1]]))
  list(percall = pc, ref = list())
}

# -- Resolve a5R libraries ----------------------------------------------------
ensure_a5r <- function(version) {
  if (identical(version, "installed")) return(NULL)
  if (dir.exists(version)) return(normalizePath(version))
  lib <- file.path(lib_root, paste0("a5R-", version))
  if (!file.exists(file.path(lib, "a5R", "DESCRIPTION"))) {
    message(sprintf(">>> Installing a5R %s into %s (compiles Rust; takes a few minutes)", version, lib))
    dir.create(lib, showWarnings = FALSE, recursive = TRUE)
    url <- sprintf("https://cran.r-project.org/src/contrib/Archive/a5R/a5R_%s.tar.gz", version)
    callr::r(
      function(url, lib) install.packages(url, repos = NULL, type = "source", lib = lib),
      args = list(url = url, lib = lib),
      show = TRUE
    )
  }
  lib
}

# -- Run ----------------------------------------------------------------------
runs <- list()
for (v in versions) {
  lib <- ensure_a5r(v)
  message(sprintf(">>> Benchmarking a5R (%s)...", v))
  runs[[length(runs) + 1]] <- callr::r(
    bench_a5r,
    args = list(coord = coord, a5_resolution = a5_resolution, k = grid_disk_k,
                polygon_wkt = polygon_wkt, percall_n = percall_n),
    libpath = c(lib, .libPaths())
  )
}
message(">>> Benchmarking h3o...")
runs[[length(runs) + 1]] <- callr::r(
  bench_h3o,
  args = list(coord = coord, h3_resolution = h3_resolution, k = grid_disk_k,
              polygon = polygon, percall_n = percall_n)
)

pc <- do.call(rbind, lapply(runs, `[[`, "percall"))
percall_ref <- do.call(c, lapply(runs, `[[`, "ref"))

# -- Output -------------------------------------------------------------------
ops <- names(percall_n)
impls <- unique(pc$impl)
tab <- sapply(ops, function(op) sapply(impls, function(i) {
  v <- pc$median_us[pc$operation == op & pc$impl == i]
  if (length(v)) formatC(v, format = "f", digits = 2, big.mark = ",") else "N/A"
}))
tab <- matrix(tab, nrow = length(impls), dimnames = list(impls, ops))
cat("\n=== PER-CALL RESULTS (µs per call) ===\n")
print(noquote(tab))
cat("\ncells returned:\n")
print(noquote(matrix(sapply(ops, function(op) sapply(impls, function(i) {
  v <- pc$n_cells[pc$operation == op & pc$impl == i]; if (length(v)) v else NA
})), nrow = length(impls), dimnames = list(impls, ops))))

jsonlite::write_json(
  list(lang = "R (versions)", impl = paste(impls, collapse = ", "),
       results = NULL, percall = pc, percall_ref = percall_ref),
  file.path(bench_dir, "results_versions.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = 15
)
message(sprintf(">>> Wrote %s", file.path(bench_dir, "results_versions.json")))
