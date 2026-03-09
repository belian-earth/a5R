# A5 Cross-Language Benchmark Results

**N = 10,000** random points | Resolution 10 | 2026-03-09 22:00


## Performance (median ms, 10k elements)

| Operation | DuckDB | JavaScript | Python | R (16t) | R |
|---:|---:|---:|---:|---:|---:|
| lonlat_to_cell | 40.80 | 267.88 | 4938.21 | **5.35** | 34.92 |
| cell_to_lonlat | 12.40 | 38.15 | 1281.42 | **1.67** | 6.80 |
| cell_to_boundary | 73.55 | 105.47 | 3194.82 | **6.11** | 23.81 |
| get_resolution | 1.29 | 0.60 | 82.94 | **0.28** | 0.29 |
| cell_to_parent | 1.36 | 2.55 | 164.57 | 0.56 | **0.49** |
| cell_to_children | 0.26 | **0.01** | 0.12 | — | 0.03 |
| compact | 0.62 | **0.02** | 0.18 | — | 0.02 |
| uncompact | 0.59 | **0.02** | 0.30 | — | 0.05 |
| cell_area | 0.22 | **0.00** | 0.03 | — | 0.19 |

## Correctness

All implementations produce identical results for the same inputs.

**Input:** `lonlat_to_cell(-3.19, 55.95, resolution = 5)`

| Value | DuckDB | JavaScript | Python | R |
|---|---|---|---|---|
| Cell (hex) | 633e000000000000 | 633e000000000000 | 633e000000000000 | 633e000000000000 |
| Lon | -3.28074501388 | -3.28074501388 | -3.28074501388 | -3.28074501388 |
| Lat | 56.4313493217 | 56.4313493217 | 56.4313493217 | 56.4313493217 |
| Parent | 6338000000000000 | 6338000000000000 | 6338000000000000 | 6338000000000000 |
| Area (m²) | 33207397446.6 | 33207397446.6 | 33207397446.6 | 33207397446.6 |
| Resolution | 5 | 5 | 5 | 5 |
| Children | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 | 633c800000000000, 633d800000000000, 633e800000000000, 633f800000000000 |

## Notes

- **R (a5R)**: Rust via extendr, vectorised — 10k elements processed in a single native call
- **Python (pya5)**: Pure Python — 10k individual function calls in a loop
- **JavaScript (a5-js)**: Reference TypeScript implementation — 10k calls in a loop
- **DuckDB (a5)**: Rust extension — SQL query over 10k rows (includes query overhead)
- The bulk operations (top 5 rows) primarily measure **vectorisation overhead**: R and DuckDB cross the FFI/SQL boundary once for 10k elements, while Python and JS pay per-element call overhead. This reflects realistic batch-processing performance but overstates the per-element algorithm speed difference.
- Single-element operations (bottom 4 rows) are sub-millisecond across all compiled implementations — differences at this scale are dominated by benchmarking and FFI overhead, not algorithm speed.
- **R (8t)**: Same as R but with `a5_set_threads(8L)` — parallelises vectorised operations via rayon. Scalar operations (children, compact, uncompact, cell_area) are unchanged.
- R's `cell_area` includes `units` package overhead; `cell_to_lonlat` and `cell_to_boundary` include `wk` geometry object construction.
