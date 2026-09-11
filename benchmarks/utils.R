# Shared helpers for the a5R benchmark suite.
#
# Mirrors benchmarks/utils.ts in the TypeScript repo and benches/common/mod.rs
# in a5-rs: the same PRNG, the same seed and the same sampling, so every port
# benchmarks identical inputs.

#' Deterministic PRNG (mulberry32), bit-for-bit the TypeScript `createRandom`.
#'
#' R has no unsigned 32-bit integer, so state is kept in a double and the
#' wrapping multiply is done in 16-bit halves to stay exact.
create_random <- function(seed = 42) {
  two32 <- 4294967296
  u32 <- function(x) x %% two32
  mul32 <- function(a, b) {
    a_lo <- a %% 65536
    a_hi <- (a - a_lo) / 65536
    b_lo <- b %% 65536
    b_hi <- (b - b_lo) / 65536
    u32(a_lo * b_lo + ((a_hi * b_lo + a_lo * b_hi) %% 65536) * 65536)
  }
  signed <- function(x) if (x >= 2147483648) x - two32 else x
  xor32 <- function(a, b) u32(bitwXor(as.integer(signed(a)), as.integer(signed(b))))
  or32 <- function(a, b) u32(bitwOr(as.integer(signed(a)), as.integer(signed(b))))
  shr <- function(x, k) x %/% 2^k

  a <- u32(seed)
  function() {
    a <<- u32(a + 1831565813) # 0x6d2b79f5
    t <- a
    t <- mul32(xor32(t, shr(t, 15)), or32(t, 1))
    t <- xor32(t, u32(t + mul32(xor32(t, shr(t, 7)), or32(t, 61))))
    xor32(t, shr(t, 14)) / two32
  }
}

#' Points distributed uniformly over the sphere (area-uniform in latitude).
#' Returns a data frame with `lon` and `lat` columns.
sample_points <- function(n, seed = 42) {
  random <- create_random(seed)
  lon <- numeric(n)
  lat <- numeric(n)
  for (i in seq_len(n)) {
    lon[i] <- 360 * random() - 180
    lat[i] <- asin(2 * random() - 1) * 180 / pi
  }
  data.frame(lon = lon, lat = lat)
}

#' Cells of uniformly distributed points at the given resolution.
sample_cells <- function(resolution, n, seed = 42) {
  p <- sample_points(n, seed)
  a5R::a5_lonlat_to_cell(p$lon, p$lat, resolution = resolution)
}

#' A country outline from the shared fixture as WKT (outer ring only, as in
#' the fixture), for `a5_polygon_to_cells()`.
load_country <- function(name) {
  path <- file.path(bench_dir(), "fixtures", "countries.json")
  countries <- jsonlite::fromJSON(path, simplifyVector = FALSE)$country
  hit <- Filter(function(c) identical(c$name, name), countries)
  if (length(hit) == 0) stop("country `", name, "` not found in fixture")
  rings <- vapply(hit[[1]]$polygon, function(ring) {
    coords <- vapply(ring, function(p) sprintf("%.7f %.7f", p[[1]], p[[2]]), "")
    paste0("(", paste(coords, collapse = ", "), ")")
  }, "")
  wk::wkt(paste0("POLYGON (", paste(rings, collapse = ", "), ")"))
}

bench_dir <- function() {
  arg <- grep("^--file=", commandArgs(), value = TRUE)
  if (length(arg)) dirname(normalizePath(sub("^--file=", "", arg[1]))) else "benchmarks"
}

# --- Result collection ---------------------------------------------------------

the_results <- new.env(parent = emptyenv())
the_results$rows <- list()
the_results$group <- NA_character_

#' Name the group that subsequent `bench_case()` calls belong to.
bench_group <- function(name) {
  the_results$group <- name
  invisible(name)
}

#' Time one expression and record it. `n` is the number of elements the
#' expression processes in one call, so per-element cost can be derived.
bench_case <- function(name, expr, n = 1L) {
  # The expression must reach bench::mark() unevaluated, so splice its AST
  # into the call rather than passing the promise through.
  call <- bquote(bench::mark(
    .(substitute(expr)),
    min_time = as.numeric(Sys.getenv("BENCH_TIME", "0.5")),
    min_iterations = 5,
    check = FALSE,
    memory = FALSE,
    filter_gc = FALSE
  ))
  # A case may use an API the baseline commit lacks (CI runs the PR's
  # benchmark files against both); skip it rather than abort the run, and
  # compare.R will report it as new.
  gc(FALSE) # start each case from a settled heap so minima are comparable
  res <- tryCatch(eval(call, parent.frame()), error = function(e) e)
  if (inherits(res, "error")) {
    cat(sprintf("  %-48s skipped: %s
", name, conditionMessage(res)))
    return(invisible(NULL))
  }
  times <- as.numeric(res$time[[1]])
  row <- data.frame(
    group = the_results$group,
    name = name,
    n = as.integer(n),
    median_ns = stats::median(times) * 1e9,
    min_ns = min(times) * 1e9,
    iterations = length(times),
    stringsAsFactors = FALSE
  )
  the_results$rows[[length(the_results$rows) + 1]] <- row
  cat(sprintf("  %-48s %10s  (%d iterations)\n", name, format_ns(row$median_ns), row$iterations))
  invisible(row)
}

bench_results <- function() {
  do.call(rbind, the_results$rows)
}

format_ns <- function(ns) {
  if (ns < 1e3) sprintf("%.1fns", ns)
  else if (ns < 1e6) sprintf("%.2fµs", ns / 1e3)
  else if (ns < 1e9) sprintf("%.2fms", ns / 1e6)
  else sprintf("%.2fs", ns / 1e9)
}
