#!/usr/bin/env Rscript
# A5 R benchmarks: a5R (installed version) and h3o.
# Outputs results_r.json and results_r_mt.json for cross-language comparison.

suppressPackageStartupMessages({
  library(a5R)
  library(h3o)
  library(bench)
})

bench_dir <- "/home/hugh/belian/a5R/benchmarks"
A5R_V <- sprintf("a5R %s", packageVersion("a5R"))
H3O_V <- sprintf("h3o %s", packageVersion("h3o"))

# -- Bulk test data -----------------------------------------------------------
set.seed(42)
n <- 10000L
lons <- runif(n, -180, 180)
lats <- runif(n, -85, 85)
res <- 10L

cells <- a5_lonlat_to_cell(lons, lats, resolution = res)
single_cell <- cells[1]
parent_cell <- a5_cell_to_parent(single_cell, resolution = 3L)
children <- a5_cell_to_children(parent_cell, resolution = 5L)

# -- Per-call parameters (Takashi's micro-benchmark) --------------------------
coord <- c(139.70033506856208, 35.690624903733436)
a5_res <- 12L
h3_res <- 8L
k <- 10L
polygon <- matrix(c(
  132.3555094, 34.3465028, 132.4945511, 34.3288744, 132.5876105, 34.4237528,
  132.6023905, 34.5338573, 132.4075132, 34.5600083, 132.2920101, 34.5022848,
  132.2575233, 34.4065923, 132.3555094, 34.3465028
), ncol = 2, byrow = TRUE)
polygon_wkt <- wk::wkt(sprintf(
  "POLYGON ((%s))",
  paste(sprintf("%.7f %.7f", polygon[, 1], polygon[, 2]), collapse = ", ")
))
polygon_sfc <- sf::st_sfc(sf::st_polygon(list(polygon)), crs = 4326)
percall_n <- c(lonlat_to_cell = 1000L, grid_disk = 200L, polygon_to_cells = 200L)

# -- Bulk benchmarks (single-threaded) ----------------------------------------
a5_set_threads(1L)
results <- bench::mark(
  lonlat_to_cell = a5_lonlat_to_cell(lons, lats, resolution = res),
  cell_to_lonlat = a5_cell_to_lonlat(cells),
  cell_to_boundary = a5_cell_to_boundary(cells),
  get_resolution = a5_get_resolution(cells),
  cell_to_parent = a5_cell_to_parent(cells),
  cell_to_children = a5_cell_to_children(single_cell, resolution = res + 2L),
  compact = a5_compact(children),
  uncompact = a5_uncompact(a5_compact(children), resolution = 5L),
  cell_area = a5_cell_area(0:30),
  min_iterations = 10,
  check = FALSE
)

# -- Bulk benchmarks (multi-threaded) -----------------------------------------
# Only vectorised functions benefit from threading; scalar ops are unchanged.
mt_threads <- 16L
a5_set_threads(mt_threads)
results_mt <- bench::mark(
  lonlat_to_cell = a5_lonlat_to_cell(lons, lats, resolution = res),
  cell_to_lonlat = a5_cell_to_lonlat(cells),
  cell_to_boundary = a5_cell_to_boundary(cells),
  get_resolution = a5_get_resolution(cells),
  cell_to_parent = a5_cell_to_parent(cells),
  min_iterations = 10,
  check = FALSE
)
a5_set_threads(1L)

# -- Per-call benchmarks ------------------------------------------------------
a5_cell1 <- a5_lonlat_to_cell(coord[1], coord[2], resolution = a5_res)
h3_cell1 <- h3_from_xy(coord[1], coord[2], h3_res)

percall_one <- function(impl, op, expr) {
  # The expression must reach bench::mark unevaluated, so splice its AST in.
  call <- bquote(bench::mark(.(substitute(expr)), iterations = .(percall_n[[op]]),
                             check = FALSE, memory = FALSE, filter_gc = FALSE))
  b <- eval(call, parent.frame())
  data.frame(impl = impl, lang = "R", operation = op,
             median_us = as.numeric(b$median) * 1e6, stringsAsFactors = FALSE)
}

pc <- rbind(
  percall_one(A5R_V, "lonlat_to_cell", a5_lonlat_to_cell(coord[1], coord[2], resolution = a5_res)),
  percall_one(A5R_V, "grid_disk", a5_grid_disk(a5_cell1, k)),
  percall_one(A5R_V, "polygon_to_cells", a5_polygon_to_cells(polygon_wkt, a5_res)),
  percall_one(H3O_V, "lonlat_to_cell", h3_from_xy(coord[1], coord[2], h3_res)),
  percall_one(H3O_V, "grid_disk", grid_disk(h3_cell1, k)),
  # "centroid" matches a5's centre containment and h3-py's default.
  percall_one(H3O_V, "polygon_to_cells", sfc_to_cells(polygon_sfc, h3_res, containment = "centroid"))
)
pc$n_cells <- c(
  1L, length(a5_grid_disk(a5_cell1, k)), length(a5_polygon_to_cells(polygon_wkt, a5_res)),
  1L, length(grid_disk(h3_cell1, k)[[1]]),
  length(sfc_to_cells(polygon_sfc, h3_res, containment = "centroid")[[1]])
)
percall_ref <- setNames(list(list(
  cell = as.character(a5_cell1), grid_disk_n = pc$n_cells[2], polygon_n = pc$n_cells[3]
)), A5R_V)

# -- Correctness reference values ---------------------------------------------
ref_cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5L)
ref_lonlat <- a5_cell_to_lonlat(ref_cell)
ref <- list(
  cell = as.character(ref_cell),
  lon = unname(wk::wk_coords(ref_lonlat)$x),
  lat = unname(wk::wk_coords(ref_lonlat)$y),
  parent = as.character(a5_cell_to_parent(ref_cell)),
  children = sort(as.character(a5_cell_to_children(ref_cell))),
  area_m2 = as.numeric(a5_cell_area(5L)),
  resolution = a5_get_resolution(ref_cell)
)

# -- Output -------------------------------------------------------------------
to_df <- function(b) data.frame(
  operation = as.character(b$expression),
  median_ms = as.numeric(b$median) * 1000,
  stringsAsFactors = FALSE
)
out <- to_df(results)
out_mt <- merge(out["operation"], to_df(results_mt), by = "operation", all.x = TRUE)

cat(sprintf("=== BULK RESULTS (%s, 1 thread) ===\n", A5R_V))
print(out, row.names = FALSE)
cat(sprintf("\n=== BULK RESULTS (%s, %d threads) ===\n", A5R_V, mt_threads))
print(out_mt, row.names = FALSE)
cat("\n=== PER-CALL RESULTS (µs per call) ===\n")
print(pc, row.names = FALSE)
cat("\n=== REFERENCE VALUES ===\n")
cat(jsonlite::toJSON(ref, auto_unbox = TRUE, pretty = TRUE, digits = 15), "\n")

jsonlite::write_json(
  list(lang = "R", impl = A5R_V, results = out, reference = ref,
       percall = pc, percall_ref = percall_ref),
  file.path(bench_dir, "results_r.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = 15
)
jsonlite::write_json(
  list(lang = sprintf("R (%dt)", mt_threads), impl = A5R_V, results = out_mt, reference = ref),
  file.path(bench_dir, "results_r_mt.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = 15
)
