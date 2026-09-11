#!/usr/bin/env Rscript
# Compare two benchmark result files and fail on regressions.
#
#   Rscript benchmarks/compare.R <baseline.json> <current.json> [threshold%]
#
# Mirrors scripts/compare_benchmarks.py in the other ports: prints
# GitHub-flavoured markdown for $GITHUB_STEP_SUMMARY and exits non-zero if any
# benchmark regressed by more than the threshold (default 15%). The
# comparison keys off the minimum sample per case, as the TypeScript and
# Python ports do: R's garbage collector perturbs individual samples of the
# allocation-heavy cases enough that medians of two identical builds can
# differ by tens of percent, while minima are stable.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript benchmarks/compare.R <baseline.json> <current.json> [threshold%]")
}
threshold <- if (length(args) > 2) as.numeric(args[3]) else 15

load <- function(path) {
  d <- jsonlite::fromJSON(path)$benchmarks
  stats::setNames(d$min_ns, paste(d$group, d$name, sep = " / "))
}
base <- load(args[1])
cur <- load(args[2])
if (!length(cur)) stop("No results in ", args[2])

fmt_time <- function(ns) {
  ifelse(ns < 1e3, sprintf("%.1fns", ns),
  ifelse(ns < 1e6, sprintf("%.2fµs", ns / 1e3),
  ifelse(ns < 1e9, sprintf("%.2fms", ns / 1e6), sprintf("%.2fs", ns / 1e9))))
}
fmt_delta <- function(d) sprintf("%s%.1f%%", ifelse(d >= 0, "+", ""), d)
table <- function(rows) c(
  "| benchmark | baseline | current | change |",
  "| --- | ---: | ---: | ---: |",
  sprintf("| %s | %s | %s | %s |", rows$name, rows$baseline, rows$current, rows$change)
)

common <- intersect(names(cur), names(base))
added <- setdiff(names(cur), names(base))
removed <- setdiff(names(base), names(cur))
delta <- 100 * (cur[common] - base[common]) / base[common]
rows <- data.frame(
  name = common, baseline = fmt_time(base[common]), current = fmt_time(cur[common]),
  change = fmt_delta(delta), delta = delta, stringsAsFactors = FALSE
)
regressions <- rows[rows$delta > threshold, ]
regressions <- regressions[order(-regressions$delta), ]
gains <- rows[rows$delta < -threshold, ]
gains <- gains[order(gains$delta), ]
bold <- function(r) { r$change <- paste0("**", r$change, "**"); r }

all_rows <- rbind(
  rows[, c("name", "baseline", "current", "change")],
  if (length(added)) data.frame(name = added, baseline = "—", current = fmt_time(cur[added]), change = "new"),
  if (length(removed)) data.frame(name = removed, baseline = fmt_time(base[removed]), current = "—", change = "removed")
)

out <- c(
  "## Benchmark comparison", "",
  "_Times are the minimum sample per benchmark (one vectorised call per case)._", "",
  if (nrow(regressions)) c(
    sprintf("### ❌ %d regression%s above %g%%", nrow(regressions), if (nrow(regressions) == 1) "" else "s", threshold), "",
    table(bold(regressions)), ""
  ) else c(sprintf("### ✅ No regressions above %g%%", threshold), ""),
  if (nrow(gains)) c(
    sprintf("### 🚀 %d gain%s above %g%%", nrow(gains), if (nrow(gains) == 1) "" else "s", threshold), "",
    table(bold(gains)), ""
  ),
  if (length(added) || length(removed)) c(
    sprintf("_%d benchmark(s) added, %d removed (not compared)._", length(added), length(removed)), ""
  ),
  "<details>", sprintf("<summary>All results (%d benchmarks)</summary>", nrow(all_rows)), "",
  table(all_rows), "", "</details>"
)
cat(out, sep = "\n")
quit(status = if (nrow(regressions)) 1L else 0L)
