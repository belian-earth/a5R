# Benchmark: blob vs hex representation
#
# Run on main branch first, then on cell-as-blob branch.
# Saves results to scratch/bench_<branch>.rds

library(a5R)
library(bench)

branch <- system("git rev-parse --abbrev-ref HEAD", intern = TRUE)
cat("Branch:", branch, "\n\n")

set.seed(42)
n <- 1e6L

lon <- runif(n, -180, 180)
lat <- runif(n, -80, 80)
res <- rep(10L, n)

cat("=== Benchmarking", n, "cells ===\n\n")

results <- list()

# 1. lonlat_to_cell
cat("1. a5_lonlat_to_cell\n")
results$lonlat_to_cell <- bench::mark(
  a5_lonlat_to_cell(lon, lat, res),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
cells <- a5_lonlat_to_cell(lon, lat, res)
print(results$lonlat_to_cell[, 1:6])

# 2. cell_to_lonlat
cat("\n2. a5_cell_to_lonlat\n")
results$cell_to_lonlat <- bench::mark(
  a5_cell_to_lonlat(cells),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$cell_to_lonlat[, 1:6])

# 3. get_resolution
cat("\n3. a5_get_resolution\n")
results$get_resolution <- bench::mark(
  a5_get_resolution(cells),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$get_resolution[, 1:6])

# 4. cell_to_parent
cat("\n4. a5_cell_to_parent\n")
results$cell_to_parent <- bench::mark(
  a5_cell_to_parent(cells),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$cell_to_parent[, 1:6])

# 5. cell_to_boundary (WKB)
cat("\n5. a5_cell_to_boundary\n")
results$cell_to_boundary <- bench::mark(
  a5_cell_to_boundary(cells),
  iterations = 5, check = FALSE, filter_gc = FALSE
)
print(results$cell_to_boundary[, 1:6])

# 6. compact (50k cells)
cat("\n6. a5_compact (50k)\n")
cells_50k <- cells[1:50000]
results$compact <- bench::mark(
  a5_compact(cells_50k),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$compact[, 1:6])

# 7. uncompact
cat("\n7. a5_uncompact (1 cell -> res 15)\n")
parent5 <- a5_cell_to_parent(cells[1], resolution = 5L)
results$uncompact <- bench::mark(
  a5_uncompact(parent5, resolution = 15L),
  iterations = 5, check = FALSE, filter_gc = FALSE
)
print(results$uncompact[, 1:6])

# 8. format / as.character
cat("\n8. format(cells)\n")
results$format <- bench::mark(
  format(cells),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$format[, 1:6])

cat("\n9. as.character(cells)\n")
results$as_character <- bench::mark(
  as.character(cells),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$as_character[, 1:6])

# 9. a5_cell() from character
hex <- as.character(cells)
cat("\n10. a5_cell(hex_strings)\n")
results$from_char <- bench::mark(
  a5_cell(hex),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$from_char[, 1:6])

# 10. grid_disk (single cell, k=5)
cat("\n11. a5_grid_disk (k=5)\n")
one <- cells[1]
results$grid_disk <- bench::mark(
  a5_grid_disk(one, k = 5L),
  iterations = 20, check = FALSE, filter_gc = FALSE
)
print(results$grid_disk[, 1:6])

# 11. distance (100k pairs)
cat("\n12. a5_cell_distance (100k pairs)\n")
from_100k <- cells[1:100000]
to_100k <- cells[100001:200000]
results$distance <- bench::mark(
  a5_cell_distance(from_100k, to_100k),
  iterations = 10, check = FALSE, filter_gc = FALSE
)
print(results$distance[, 1:6])

# Object sizes
cat("\n=== Object sizes ===\n")
cat("a5_cell (", n, "):", format(object.size(cells), units = "MB"), "\n")
cat("character (", n, "):", format(object.size(hex), units = "MB"), "\n")

# Save results
outfile <- paste0("scratch/bench_", branch, ".rds")
saveRDS(results, outfile)
cat("\nResults saved to", outfile, "\n")
