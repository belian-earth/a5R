#!/usr/bin/env Rscript
# A5R benchmarks — outputs JSON for cross-language comparison

library(a5R)
library(bench)

# -- Test data ----------------------------------------------------------------
set.seed(42)
n <- 10000L
lons <- runif(n, -180, 180)
lats <- runif(n, -85, 85)
res <- 10L

cells <- a5_lonlat_to_cell(lons, lats, resolution = res)
single_cell <- cells[1]
parent_cell <- a5_cell_to_parent(single_cell, resolution = 3L)

# Pre-generate children for compact benchmark
children <- a5_cell_to_children(parent_cell, resolution = 5L)

# -- Benchmarks (single-threaded) ---------------------------------------------
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

# -- Benchmarks (multi-threaded, 8 threads) -----------------------------------
# Only vectorised functions benefit from threading; scalar ops are unchanged.
mt_threads <- 8L
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

# -- Correctness reference values ---------------------------------------------
ref_cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5L)
ref_lonlat <- a5_cell_to_lonlat(ref_cell)
ref_parent <- a5_cell_to_parent(ref_cell)
ref_children <- a5_cell_to_children(ref_cell)
ref_area <- as.numeric(a5_cell_area(5L))

ref <- list(
  cell = as.character(ref_cell),
  lon = unname(wk::wk_coords(ref_lonlat)$x),
  lat = unname(wk::wk_coords(ref_lonlat)$y),
  parent = as.character(ref_parent),
  children = sort(as.character(ref_children)),
  area_m2 = ref_area,
  resolution = a5_get_resolution(ref_cell)
)

# -- Output -------------------------------------------------------------------
out <- data.frame(
  operation = as.character(results$expression),
  median_ms = as.numeric(results$median) * 1000,
  mem_alloc_kb = as.numeric(results$mem_alloc) / 1024
)

# Build mt output with NA for non-vectorised ops
mt_df <- data.frame(
  operation = as.character(results_mt$expression),
  median_ms = as.numeric(results_mt$median) * 1000,
  mem_alloc_kb = as.numeric(results_mt$mem_alloc) / 1024
)
out_mt <- merge(out["operation"], mt_df, by = "operation", all.x = TRUE)

cat("=== BENCHMARK RESULTS (R / a5R, 1 thread) ===\n")
print(out, row.names = FALSE)
cat(sprintf("\n=== BENCHMARK RESULTS (R / a5R, %d threads) ===\n", mt_threads))
print(out_mt, row.names = FALSE)
cat("\n=== REFERENCE VALUES ===\n")
cat(jsonlite::toJSON(ref, auto_unbox = TRUE, pretty = TRUE, digits = 15), "\n")

# Write JSON for summary script
jsonlite::write_json(
  list(lang = "R", results = out, reference = ref),
  "/home/hugh/belian/a5R/benchmarks/results_r.json",
  auto_unbox = TRUE, pretty = TRUE, digits = 15
)

jsonlite::write_json(
  list(lang = sprintf("R (%dt)", mt_threads), results = out_mt, reference = ref),
  "/home/hugh/belian/a5R/benchmarks/results_r_mt.json",
  auto_unbox = TRUE, pretty = TRUE, digits = 15
)
