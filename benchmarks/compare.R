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
# differ by tens of percent, while minima are usually stable. Usually: a case
# that allocates on every call (as.character of 100k cells) collects garbage
# in nearly every iteration, so its minimum is the one lucky iteration that
# escaped a collection, and that can differ by a third between identical
# builds. A real regression moves the whole distribution, so a case fails only
# when its minimum and its median both regress past the threshold.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript benchmarks/compare.R <baseline.json> <current.json> [threshold%]")
}
threshold <- if (length(args) > 2) as.numeric(args[3]) else 15

load <- function(path, stat = "min_ns") {
  d <- jsonlite::fromJSON(path)$benchmarks
  stats::setNames(d[[stat]], paste(d$group, d$name, sep = " / "))
}
base <- load(args[1])
cur <- load(args[2])
if (!length(cur)) stop("No results in ", args[2])
base_med <- load(args[1], "median_ns")
cur_med <- load(args[2], "median_ns")

fmt_time <- function(ns) {
  ifelse(ns < 1e3, sprintf("%.1fns", ns),
  ifelse(ns < 1e6, sprintf("%.2fµs", ns / 1e3),
  ifelse(ns < 1e9, sprintf("%.2fms", ns / 1e6), sprintf("%.2fs", ns / 1e9))))
}
fmt_delta <- function(d) sprintf("%s%.1f%%", ifelse(d >= 0, "+", ""), d)
table <- function(rows) c(
  "| benchmark | baseline | current | change | median change |",
  "| --- | ---: | ---: | ---: | ---: |",
  sprintf("| %s | %s | %s | %s | %s |", rows$name, rows$baseline, rows$current, rows$change, rows$median)
)

common <- intersect(names(cur), names(base))
added <- setdiff(names(cur), names(base))
removed <- setdiff(names(base), names(cur))
delta <- 100 * (cur[common] - base[common]) / base[common]
delta_med <- 100 * (cur_med[common] - base_med[common]) / base_med[common]
rows <- data.frame(
  name = common, baseline = fmt_time(base[common]), current = fmt_time(cur[common]),
  change = fmt_delta(delta), median = fmt_delta(delta_med), delta = delta,
  delta_med = delta_med, stringsAsFactors = FALSE
)
regressions <- rows[rows$delta > threshold & rows$delta_med > threshold, ]
regressions <- regressions[order(-regressions$delta), ]
# minimum past the threshold but not the median: shown, not failed
unsettled <- rows[rows$delta > threshold & !(rows$delta_med > threshold), ]
gains <- rows[rows$delta < -threshold & rows$delta_med < -threshold, ]
gains <- gains[order(gains$delta), ]
bold <- function(r) { r$change <- paste0("**", r$change, "**"); r }

all_rows <- rbind(
  rows[, c("name", "baseline", "current", "change", "median")],
  if (length(added)) data.frame(name = added, baseline = "—", current = fmt_time(cur[added]), change = "new", median = ""),
  if (length(removed)) data.frame(name = removed, baseline = fmt_time(base[removed]), current = "—", change = "removed", median = "")
)

out <- c(
  "## Benchmark comparison", "",
  "_Times are the minimum sample per benchmark (one vectorised call per case). A case fails only when its minimum and its median both regress past the threshold._", "",
  if (nrow(regressions)) c(
    sprintf("### ❌ %d regression%s above %g%%", nrow(regressions), if (nrow(regressions) == 1) "" else "s", threshold), "",
    table(bold(regressions)), ""
  ) else c(sprintf("### ✅ No regressions above %g%%", threshold), ""),
  if (nrow(unsettled)) c(
    sprintf("### ⚠️ %d minimum%s above %g%% with the median within it (not failed)", nrow(unsettled), if (nrow(unsettled) == 1) "" else "s", threshold), "",
    table(bold(unsettled)), ""
  ),
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
