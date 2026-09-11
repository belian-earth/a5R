#!/usr/bin/env Rscript
# Run the a5R benchmark suite and write results as JSON.
#
#   Rscript benchmarks/run.R [output.json]
#
# Benchmarks the installed a5R. Set BENCH_TIME (seconds per case, default
# 0.5) for more samples. Names mirror the TypeScript, Python and Rust suites;
# each R case is one vectorised call over `n` elements, so `median_ns / n` is
# the per-element figure comparable with the other ports.

suppressPackageStartupMessages({
  library(a5R)
  library(bench)
})

args <- commandArgs(trailingOnly = TRUE)
output <- if (length(args)) args[1] else "bench-results.json"

dir <- local({
  arg <- grep("^--file=", commandArgs(), value = TRUE)
  if (length(arg)) dirname(normalizePath(sub("^--file=", "", arg[1]))) else "benchmarks"
})
source(file.path(dir, "utils.R"))

a5_set_threads(1L)
cat(sprintf("a5R %s | %s | threads = 1 | BENCH_TIME = %ss\n\n",
            packageVersion("a5R"), R.version.string, Sys.getenv("BENCH_TIME", "0.5")))

files <- sort(list.files(dir, pattern = "^bench-.*\\.R$", full.names = TRUE))
for (f in files) {
  cat(basename(f), "\n")
  source(f, local = new.env(parent = globalenv()))
}

results <- bench_results()
jsonlite::write_json(
  list(
    package = "a5R",
    version = as.character(packageVersion("a5R")),
    r = R.version.string,
    date = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    benchmarks = results
  ),
  output, auto_unbox = TRUE, pretty = TRUE, digits = NA
)
cat(sprintf("\nWrote %d results to %s\n", nrow(results), output))
