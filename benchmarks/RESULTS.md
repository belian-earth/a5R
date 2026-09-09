# A5 Cross-Language Benchmark Results

**2026-09-09 16:51** | 12th Gen Intel(R) Core(TM) i7-12700H | R version 4.6.1 (2026-06-24)


Two benchmark styles are reported. The **bulk** table is the original
cross-language benchmark: 10,000 random points at resolution 10. The
**per-call** table follows the micro-benchmark written by Takashi (a5
contributor) for pya5, a5_fast and h3-py: one Tokyo point at a5 resolution 12
(H3 resolution 8), `grid_disk` with k = 10, and a 7-vertex Hiroshima polygon
with centre containment. It adds R (a5R, h3o), JavaScript (a5-js), DuckDB
(a5, h3) and earlier a5R releases.

## Bulk performance (median ms, 10k elements)

| Operation | R | R (16t) | Python (a5_fast) | DuckDB | JavaScript | Python |
|---:|---:|---:|---:|---:|---:|---:|
| lonlat_to_cell | 23.45 | **19.29** | 37.38 | 26.32 | 138.78 | 1186.93 |
| cell_to_lonlat | 3.72 | **1.02** | 8.20 | 8.38 | 30.14 | 196.16 |
| cell_to_boundary | 17.66 | **8.41** | 30.32 | 61.02 | 58.14 | 546.65 |
| get_resolution | **0.27** | 0.27 | 0.53 | 0.94 | 2.43 | 9.90 |
| cell_to_parent | 0.25 | **0.22** | 0.99 | 0.93 | 5.14 | 12.99 |
| cell_to_children | 0.06 | — | **0.00** | 0.30 | 0.01 | 0.01 |
| compact | 0.05 | — | **0.00** | 0.57 | 0.02 | 0.02 |
| uncompact | 0.11 | — | **0.00** | 0.58 | 0.02 | 0.03 |
| cell_area | 0.19 | — | **0.00** | 0.16 | 0.00 | 0.01 |

Implementations: DuckDB: duckdb-a5 4916fb8 (duckdb 1.5.5); JavaScript: a5-js 0.10.0; Python (a5_fast): a5_fast 0.2.1; Python: pya5 0.10.0; R (16t): a5R 0.6.0; R: a5R 0.6.0.

## Per-call performance (median µs per call)

| Implementation | Language | lonlat_to_cell | grid_disk (k=10) | polygon_to_cells |
|:--|:--|--:|--:|--:|
| a5R 0.6.0.9000 (dev) | R | 7.83 | **385.73** | 698.65 |
| a5R 0.6.0 | R | 35.40 | 412.19 | 724.32 |
| a5R 0.5.0 | R | 32.82 | 788.78 | 749.69 |
| a5_fast 0.2.1 | Python | 1.60 | 666.13 | N/A |
| pya5 0.10.0 | Python | 6.35 | 19,710.83 | 24,249.40 |
| a5-js 0.10.0 | JavaScript | **1.06** | 4,779.92 | 4,138.03 |
| duckdb-a5 4916fb8 | DuckDB | 111.83 | 630.38 | **673.92** |
| h3o 0.3.0 | R | 2.56 | 159.53 | 1,758.89 |
| h3-py 4.5.0 | Python | **0.44** | **84.94** | **747.50** |
| duckdb-h3 v1.5.5 | DuckDB | 104.92 | 417.02 | 1,415.19 |

Bold marks the fastest A5 and the fastest H3 implementation in each column.

### Cells returned

| Implementation | lonlat_to_cell | grid_disk (k=10) | polygon_to_cells |
|:--|--:|--:|--:|
| a5R 0.6.0.9000 (dev) | 1 | 72 | 62 |
| a5R 0.6.0 | 1 | 72 | 62 |
| a5R 0.5.0 | 1 | 72 | 62 |
| a5_fast 0.2.1 | 1 | 72 | N/A |
| pya5 0.10.0 | 1 | 72 | 62 |
| a5-js 0.10.0 | 1 | 72 | 62 |
| duckdb-a5 4916fb8 | 1 | 72 | 62 |
| h3o 0.3.0 | 1 | 331 | 1,022 |
| h3-py 4.5.0 | 1 | 331 | 1,022 |
| duckdb-h3 v1.5.5 | 1 | 331 | 1,022 |

## Correctness

### Bulk reference

**Input:** `lonlat_to_cell(-3.19, 55.95, resolution = 5)`

| Value | DuckDB | JavaScript | Python (a5_fast) | Python | R |
|---|---|---|---|---|---|
| Cell (hex) | 633e000000000000 | 633e000000000000 | 633e000000000000 | 633e000000000000 | 633e000000000000 |
| Lon | -3.28074501388 | -3.28074501388 | -3.28074501388 | -3.28074501388 | -3.28074501388 |
| Lat | 56.4313493217 | 56.4313493217 | 56.4313493217 | 56.4313493217 | 56.4313493217 |
| Parent | 6338000000000000 | 6338000000000000 | 6338000000000000 | 6338000000000000 | 6338000000000000 |
| Area (m²) | 33207397446.6 | 33207397446.6 | 33207397446.6 | 33207397446.6 | 33207397446.6 |
| Resolution | 5 | 5 | 5 | 5 | 5 |
| Children | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 |

### Per-call reference (A5 implementations)

**Input:** Tokyo point at resolution 12; disk k = 10; Hiroshima polygon.

| Implementation | Cell (hex) | grid_disk cells | polygon cells |
|:--|:--|--:|--:|
| duckdb-a5 4916fb8 | 872f840800000000 | 72 | 62 |
| a5-js 0.10.0 | 872f840800000000 | 72 | 62 |
| pya5 0.10.0 | 872f840800000000 | 72 | 62 |
| a5_fast 0.2.1 | 872f840800000000 | 72 | N/A |
| a5R 0.6.0 | 872f840800000000 | 72 | 62 |
| a5R 0.5.0 | 872f840800000000 | 72 | 62 |
| a5R 0.6.0.9000 (dev) | 872f840800000000 | 72 | 62 |

All A5 implementations agree.

## Notes

- **R (a5R)**: Rust via extendr, vectorised. Bulk rows cross the FFI boundary once for 10k elements. **R (16t)** sets `a5_set_threads(16L)`; only the vectorised rows change.
- **Python (pya5)**: pure Python, 10k individual calls in a loop. **Python (a5_fast)**: Rust via PyO3, same loop of scalar calls (it also offers `lonlat_to_cell_batch()`, not used here).
- **JavaScript (a5-js)**: reference TypeScript implementation, 10k calls in a loop.
- **DuckDB**: a5 and h3 community extensions. Bulk rows are SQL over 10k rows; per-call rows are one-row queries and so include parse, plan and execute overhead of roughly 100 µs.
- Bulk rows primarily measure **vectorisation overhead**: R and DuckDB cross the native boundary once, Python and JS pay per-element call overhead. Sub-millisecond rows are dominated by benchmarking and FFI overhead.
- a5 resolution 12 cells (~2.0 km²) are larger than H3 resolution 8 cells (~0.74 km²), so H3 returns more cells for the same disk and polygon (see *Cells returned*). Per-cell throughput is the fairer comparison for those two columns.
- For a single point, a5R's Rust call takes a few microseconds; the rest of its `lonlat_to_cell` figure is R-side overhead (vctrs casting and `a5_cell` record construction) that is paid once per call and vanishes in the bulk rows.
- h3-py's `LatLngPoly` takes (lat, lng) pairs; the polygon is swapped before the call so that H3 covers the same area as A5.
- A5 `lonlat_to_cell` (crate 0.10 and a5-js 0.10) caches the last pentagon and returns early when the next point falls inside it, so the per-call column, which repeats one point, measures the cache-hit path plus call overhead. The bulk row over 10k distinct points measures the uncached algorithm (about 2.3 µs per point in Rust versus 1.2 µs for H3). H3 has no such cache.
- Run-to-run noise is around 10% for most rows and higher for sub-millisecond ones; treat differences under that as ties.
- Earlier a5R releases are benchmarked by `bench_versions.R` in separate R sessions; pass version numbers to compare others. Run everything with `benchmarks/run_all.sh`, which also upgrades the Python and JavaScript dependencies to their latest releases.
