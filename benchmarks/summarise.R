#!/usr/bin/env Rscript
# Read benchmark JSON files and produce RESULTS.md

dir <- "/home/hugh/belian/a5R/benchmarks"
files <- sort(list.files(dir, pattern = "^results_.*\\.json$", full.names = TRUE))
if (length(files) == 0) stop("No result files found")

runs <- lapply(files, function(f) jsonlite::fromJSON(f, simplifyVector = TRUE))
runs <- Filter(function(x) !is.null(x$lang), runs)  # skip results_threads.json etc.

# -- Bulk table ---------------------------------------------------------------
bulk_runs <- Filter(function(x) !is.null(x$results) && length(x$results) > 0, runs)
bulk_df <- do.call(rbind, lapply(bulk_runs, function(x) {
  r <- x$results[, c("operation", "median_ms")]
  r$lang <- x$lang
  r
}))
wide <- reshape(bulk_df, idvar = "operation", timevar = "lang",
                direction = "wide", sep = "_")
names(wide) <- gsub("median_ms_", "", names(wide))

op_order <- c("lonlat_to_cell", "cell_to_lonlat", "cell_to_boundary",
              "get_resolution", "cell_to_parent", "cell_to_children",
              "compact", "uncompact", "cell_area")
wide <- wide[match(op_order, wide$operation), ]

lang_pref <- c("R", "R (16t)", "Python (a5_fast)", "DuckDB", "JavaScript", "Python")
langs <- setdiff(names(wide), "operation")
langs <- c(intersect(lang_pref, langs), setdiff(langs, lang_pref))

bulk_impls <- vapply(bulk_runs, function(x) sprintf("%s: %s", x$lang, x$impl), "")

# -- Per-call table -----------------------------------------------------------
pc <- do.call(rbind, lapply(runs, function(x) {
  if (is.null(x$percall)) return(NULL)
  x$percall[, c("impl", "lang", "operation", "median_us", "n_cells")]
}))
pc <- pc[!duplicated(pc[, c("impl", "operation")]), ]

pc_ops <- c("lonlat_to_cell", "grid_disk", "polygon_to_cells")
pc_op_labels <- c("lonlat_to_cell", "grid_disk (k=10)", "polygon_to_cells")

impl_tab <- unique(pc[, c("impl", "lang")])
impl_tab$group <- ifelse(grepl("^h3|^duckdb-h3", impl_tab$impl), 2L, 1L)
impl_tab$lang_rank <- match(impl_tab$lang, c("R", "Python", "JavaScript", "DuckDB"))
# Within a5R, the installed (highest) version first.
a5r_ver <- ifelse(grepl("^a5R ", impl_tab$impl), sub(" .*$", "", sub("^a5R ", "", impl_tab$impl)), "0")
impl_tab$ver <- numeric_version(a5r_ver)
impl_tab <- impl_tab[order(impl_tab$group, impl_tab$lang_rank, -xtfrm(impl_tab$ver), impl_tab$impl), ]
pc_impls <- impl_tab$impl

pc_cell <- function(impl, op, col) {
  v <- pc[pc$impl == impl & pc$operation == op, col]
  if (length(v) == 0 || is.na(v)) NA else v
}
fmt_us <- function(x) if (is.na(x)) "N/A" else formatC(x, format = "f", digits = 2, big.mark = ",")
fmt_n <- function(x) if (is.na(x)) "N/A" else format(x, big.mark = ",")

# Fastest per column within each group (a5 and h3), bolded.
fastest <- list()
for (op in pc_ops) for (g in 1:2) {
  imps <- impl_tab$impl[impl_tab$group == g]
  v <- vapply(imps, pc_cell, numeric(1), op = op, col = "median_us")
  if (any(!is.na(v))) fastest[[paste(op, g)]] <- imps[which.min(v)]
}

# -- Per-call correctness -----------------------------------------------------
pc_refs <- do.call(c, lapply(runs, function(x) x$percall_ref))
pc_refs <- pc_refs[!duplicated(names(pc_refs))]

# -- Bulk correctness (skip multi-threaded variants: same reference) ----------
refs <- lapply(
  Filter(function(x) !is.null(x$reference) && !grepl("\\dt\\)", x$lang), runs),
  function(x) { r <- x$reference; r$lang <- x$lang; r }
)

# -- Write markdown -----------------------------------------------------------
md <- character()
add <- function(...) md <<- c(md, paste0(...))

cpu <- tryCatch({
  l <- grep("^model name", readLines("/proc/cpuinfo"), value = TRUE)[1]
  trimws(sub("^model name\\s*:\\s*", "", l))
}, error = function(e) "unknown CPU")

add("# A5 Cross-Language Benchmark Results\n")
add("**", format(Sys.time(), "%Y-%m-%d %H:%M"), "** | ", cpu, " | ", R.version.string, "\n")
add("")
add("Two benchmark styles are reported. The **bulk** table is the original")
add("cross-language benchmark: 10,000 random points at resolution 10. The")
add("**per-call** table follows the micro-benchmark written by Takashi (a5")
add("contributor) for pya5, a5_fast and h3-py: one Tokyo point at a5 resolution 12")
add("(H3 resolution 8), `grid_disk` with k = 10, and a 7-vertex Hiroshima polygon")
add("with centre containment. It adds R (a5R, h3o), JavaScript (a5-js), DuckDB")
add("(a5, h3) and earlier a5R releases.")
add("")

# Bulk table
add("## Bulk performance (median ms, 10k elements)\n")
add("| Operation |", paste(sprintf(" %s |", langs), collapse = ""))
add("|", paste(rep("---:|", length(langs) + 1), collapse = ""))
for (i in seq_len(nrow(wide))) {
  num_vals <- sapply(langs, function(l) { v <- wide[[l]][i]; if (is.null(v) || is.na(v)) Inf else v })
  fastest_idx <- which.min(num_vals)
  vals <- sapply(seq_along(langs), function(j) {
    v <- num_vals[j]
    if (is.infinite(v)) return("—")
    txt <- sprintf("%.2f", v)
    if (j == fastest_idx) txt <- paste0("**", txt, "**")
    txt
  })
  add("| ", wide$operation[i], " |", paste(sprintf(" %s |", vals), collapse = ""))
}
add("")
add("Implementations: ", paste(bulk_impls, collapse = "; "), ".")
add("")

# Per-call table
add("## Per-call performance (median µs per call)\n")
add("| Implementation | Language |", paste(sprintf(" %s |", pc_op_labels), collapse = ""))
add("|:--|:--|", paste(rep("--:|", length(pc_ops)), collapse = ""))
for (i in seq_len(nrow(impl_tab))) {
  impl <- impl_tab$impl[i]
  vals <- sapply(pc_ops, function(op) {
    txt <- fmt_us(pc_cell(impl, op, "median_us"))
    if (identical(fastest[[paste(op, impl_tab$group[i])]], impl)) txt <- paste0("**", txt, "**")
    txt
  })
  add("| ", impl, " | ", impl_tab$lang[i], " |", paste(sprintf(" %s |", vals), collapse = ""))
}
add("")
add("Bold marks the fastest A5 and the fastest H3 implementation in each column.")
add("")
add("### Cells returned\n")
add("| Implementation |", paste(sprintf(" %s |", pc_op_labels), collapse = ""))
add("|:--|", paste(rep("--:|", length(pc_ops)), collapse = ""))
for (impl in pc_impls) {
  vals <- sapply(pc_ops, function(op) fmt_n(pc_cell(impl, op, "n_cells")))
  add("| ", impl, " |", paste(sprintf(" %s |", vals), collapse = ""))
}
add("")

# Correctness
add("## Correctness\n")
add("### Bulk reference\n")
add("**Input:** `lonlat_to_cell(-3.19, 55.95, resolution = 5)`\n")
add("| Value |", paste(sprintf(" %s |", sapply(refs, `[[`, "lang")), collapse = ""))
add("|", paste(rep("---|", length(refs) + 1), collapse = ""))
fields <- c("cell", "lon", "lat", "parent", "area_m2", "resolution")
labels <- c("Cell (hex)", "Lon", "Lat", "Parent", "Area (m²)", "Resolution")
for (j in seq_along(fields)) {
  vals <- sapply(refs, function(r) {
    v <- r[[fields[j]]]
    if (is.null(v)) return("—")
    if (is.numeric(v)) return(sprintf("%.12g", v))
    as.character(v)
  })
  add("| ", labels[j], " |", paste(sprintf(" %s |", vals), collapse = ""))
}
add("| Children |", paste(sapply(refs, function(r) {
  ch <- r$children
  if (is.null(ch)) return(" — |")
  paste0(" ", paste(ch, collapse = ", "), " |")
}), collapse = ""))
add("")
add("### Per-call reference (A5 implementations)\n")
add("**Input:** Tokyo point at resolution 12; disk k = 10; Hiroshima polygon.\n")
add("| Implementation | Cell (hex) | grid_disk cells | polygon cells |")
add("|:--|:--|--:|--:|")
for (n in names(pc_refs)) {
  r <- pc_refs[[n]]
  add("| ", n, " | ", r$cell, " | ", fmt_n(r$grid_disk_n), " | ",
      if (is.null(r$polygon_n)) "N/A" else fmt_n(r$polygon_n), " |")
}
all_cells <- unique(vapply(pc_refs, `[[`, "", "cell"))
add("")
add(if (length(all_cells) == 1) "All A5 implementations agree." else
      "**Mismatch between A5 implementations.**")
add("")

# Notes
add("## Notes\n")
add("- **R (a5R)**: Rust via extendr, vectorised. Bulk rows cross the FFI boundary once for 10k elements. **R (16t)** sets `a5_set_threads(16L)`; only the vectorised rows change.")
add("- **Python (pya5)**: pure Python, 10k individual calls in a loop. **Python (a5_fast)**: Rust via PyO3, same loop of scalar calls (it also offers `lonlat_to_cell_batch()`, not used here).")
add("- **JavaScript (a5-js)**: reference TypeScript implementation, 10k calls in a loop.")
add("- **DuckDB**: a5 and h3 community extensions. Bulk rows are SQL over 10k rows; per-call rows are one-row queries and so include parse, plan and execute overhead of roughly 100 µs.")
add("- Bulk rows primarily measure **vectorisation overhead**: R and DuckDB cross the native boundary once, Python and JS pay per-element call overhead. Sub-millisecond rows are dominated by benchmarking and FFI overhead.")
add("- a5 resolution 12 cells (~2.0 km²) are larger than H3 resolution 8 cells (~0.74 km²), so H3 returns more cells for the same disk and polygon (see *Cells returned*). Per-cell throughput is the fairer comparison for those two columns.")
add("- For a single point, a5R's Rust call takes a few microseconds; the rest of its `lonlat_to_cell` figure is R-side overhead (vctrs casting and `a5_cell` record construction) that is paid once per call and vanishes in the bulk rows.")
add("- h3-py's `LatLngPoly` takes (lat, lng) pairs; the polygon is swapped before the call so that H3 covers the same area as A5.")
add("- A5 `lonlat_to_cell` (crate 0.10 and a5-js 0.10) caches the last pentagon and returns early when the next point falls inside it, so the per-call column, which repeats one point, measures the cache-hit path plus call overhead. The bulk row over 10k distinct points measures the uncached algorithm (about 2.3 µs per point in Rust versus 1.2 µs for H3). H3 has no such cache.")
add("- Run-to-run noise is around 10% for most rows and higher for sub-millisecond ones; treat differences under that as ties.")
add("- Earlier a5R releases are benchmarked by `bench_versions.R` in separate R sessions; pass version numbers to compare others. Run everything with `benchmarks/run_all.sh`, which also upgrades the Python and JavaScript dependencies to their latest releases.")

writeLines(md, file.path(dir, "RESULTS.md"))
cat("Wrote", file.path(dir, "RESULTS.md"), "\n")
