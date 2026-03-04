#!/usr/bin/env Rscript
# A5R threading benchmarks — compare single vs multi-threaded performance

library(a5R)
library(bench)

# -- Test data ----------------------------------------------------------------
set.seed(42)
n <- 100000L
lons <- runif(n, -180, 180)
lats <- runif(n, -85, 85)
res <- 10L

cells <- a5_lonlat_to_cell(lons, lats, resolution = res)

# Grid cells for intersection benchmark
grid_cells <- a5_grid(c(-10, 50, 10, 60), resolution = 10L)
target_wkt <- "POLYGON ((-5 52, 5 52, 5 58, -5 58, -5 52))"
grid_chars <- as.character(grid_cells)

# Grid generation inputs
bbox <- c(-10, 50, 10, 60)
poly <- wk::wkt("POLYGON ((-10 50, 10 50, 10 60, -10 60, -10 50))")

thread_counts <- c(1L, 2L, 4L, 8L, 16L)

cat(sprintf("Vectorised ops: n = %s elements\n", n))
cat(sprintf("Grid ops: bbox/poly r10 = %d cells, r12 = %d cells\n",
    length(grid_cells), length(a5_grid(bbox, 12L))))
cat(sprintf("Available cores: %s\n\n", parallel::detectCores()))

# -- Vectorised function benchmarks -------------------------------------------
exprs <- rlang::exprs(
    cell_to_boundary_wkt = a5_cell_to_boundary(cells, format = "wkt"),
    cell_to_boundary_wkb = a5_cell_to_boundary(cells),
    grid_intersects      = a5R:::a5_grid_intersects_rs(grid_chars, target_wkt),
    lonlat_to_cell       = a5_lonlat_to_cell(lons, lats, resolution = res),
    cell_to_lonlat       = a5_cell_to_lonlat(cells),
    cell_to_parent       = a5_cell_to_parent(cells),
    get_resolution       = a5_get_resolution(cells),
    is_valid_cell        = a5_is_cell(cells)
)

results <- data.frame()

for (threads in thread_counts) {
    cat(sprintf("--- threads = %d ---\n", threads))
    a5_set_threads(threads)

    bm <- rlang::inject(bench::mark(!!!exprs, min_iterations = 5, check = FALSE))

    results <- rbind(results, data.frame(
        operation = as.character(bm$expression),
        threads = threads,
        median_ms = as.numeric(bm$median) * 1000,
        itr_per_sec = bm$`itr/sec`
    ))
}

# -- Grid generation benchmarks -----------------------------------------------
cat("\n--- a5_grid benchmarks ---\n")

grid_results <- data.frame()

for (threads in thread_counts) {
    cat(sprintf("--- threads = %d ---\n", threads))
    a5_set_threads(threads)

    t1 <- as.numeric(bench::mark(a5_grid(bbox, 10L), min_iterations = 3, check = FALSE)$median) * 1000
    t2 <- as.numeric(bench::mark(a5_grid(poly, 10L), min_iterations = 3, check = FALSE)$median) * 1000
    t3 <- as.numeric(bench::mark(a5_grid(bbox, 12L), min_iterations = 3, check = FALSE)$median) * 1000
    t4 <- as.numeric(bench::mark(a5_grid(poly, 12L), min_iterations = 3, check = FALSE)$median) * 1000

    grid_results <- rbind(grid_results, data.frame(
        threads = threads,
        grid_bbox_r10 = t1, grid_poly_r10 = t2,
        grid_bbox_r12 = t3, grid_poly_r12 = t4
    ))
}

a5_set_threads(1L)

# -- Compute speedups ---------------------------------------------------------
baseline <- results[results$threads == 1, c("operation", "median_ms")]
names(baseline)[2] <- "baseline_ms"
results <- merge(results, baseline, by = "operation")
results$speedup <- results$baseline_ms / results$median_ms

# -- Print vectorised results -------------------------------------------------
cat("\n=== VECTORISED FUNCTION BENCHMARKS ===\n")
cat(sprintf("n = %s\n\n", n))

for (op in unique(results$operation)) {
    cat(sprintf("  %s:\n", op))
    sub <- results[results$operation == op, ]
    sub <- sub[order(sub$threads), ]
    for (j in seq_len(nrow(sub))) {
        cat(sprintf("    %2d threads: %8.2f ms  (%.2fx)\n",
            sub$threads[j], sub$median_ms[j], sub$speedup[j]))
    }
    cat("\n")
}

# -- Print grid results -------------------------------------------------------
cat("=== a5_grid() BENCHMARKS (median ms) ===\n\n")
cat(sprintf("%8s  %14s  %14s  %14s  %14s\n", "threads", "bbox r10", "poly r10", "bbox r12", "poly r12"))
cat(strrep("-", 76), "\n")
for (i in seq_len(nrow(grid_results))) {
    r <- grid_results[i, ]
    cat(sprintf("%8d  %10.1f ms   %10.1f ms   %10.1f ms   %10.1f ms\n",
        r$threads, r$grid_bbox_r10, r$grid_poly_r10, r$grid_bbox_r12, r$grid_poly_r12))
}

cat(sprintf("\n%8s  %14s  %14s  %14s  %14s\n", "threads", "bbox r10", "poly r10", "bbox r12", "poly r12"))
cat(strrep("-", 76), "\n")
base <- grid_results[1, ]
for (i in seq_len(nrow(grid_results))) {
    r <- grid_results[i, ]
    cat(sprintf("%8d  %10.2fx      %10.2fx      %10.2fx      %10.2fx\n",
        r$threads,
        base$grid_bbox_r10 / r$grid_bbox_r10,
        base$grid_poly_r10 / r$grid_poly_r10,
        base$grid_bbox_r12 / r$grid_bbox_r12,
        base$grid_poly_r12 / r$grid_poly_r12))
}

# -- Save JSON ----------------------------------------------------------------
jsonlite::write_json(
    list(
        n = n,
        grid_n = length(grid_cells),
        cores = parallel::detectCores(),
        vectorised = results[order(results$operation, results$threads), ],
        grid = grid_results
    ),
    "benchmarks/results_threads.json",
    auto_unbox = TRUE, pretty = TRUE, digits = 6
)
cat("\nResults saved to benchmarks/results_threads.json\n")
