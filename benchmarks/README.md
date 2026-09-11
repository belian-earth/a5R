# a5R benchmarks

A throughput suite mirroring the ones in the TypeScript, Python and Rust A5
repositories: the same benchmark names, the same deterministic inputs (a
mulberry32 PRNG with seed 42, area-uniform points on the sphere, the same
country outlines) and the same regression check in CI.

Each R case is one vectorised call over `n` elements, recorded in the JSON,
so `median_ns / n` is the per-element figure comparable with the other ports,
which time a single element per iteration. The `wrapper` group is R-only and
times single-element calls to guard the R-side fast paths.

## Running locally

```sh
R CMD INSTALL .                         # benchmark the installed package
Rscript benchmarks/run.R current.json
git stash                               # or check out a baseline, reinstall
Rscript benchmarks/run.R baseline.json
Rscript benchmarks/compare.R baseline.json current.json 15
```

`BENCH_TIME` sets seconds per case (default 0.5). Threads are pinned to one.

## In CI

`.github/workflows/bench.yml` runs on every pull request: it installs the PR,
runs the suite, switches `R/`, `src/` and `NAMESPACE` to the merge-base with
`main`, reinstalls, runs again, and fails if any case regressed by more than
15%. Both runs share a runner minutes apart, so machine variance largely
cancels out.
