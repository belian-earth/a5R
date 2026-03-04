# A5 Cross-Language Benchmark Results

**N = 10,000** random points | Resolution 10 | 2026-03-04 09:20


## Performance (median ms, 10k elements)

| Operation | DuckDB | JavaScript | Python | R (8t) | R |
|---:|---:|---:|---:|---:|---:|
| lonlat_to_cell | 38.45 | 263.99 | 4865.63 | **11.34** | 42.84 |
| cell_to_lonlat | 11.86 | 39.67 | 1230.64 | **2.14** | 8.43 |
| cell_to_boundary | 69.67 | 89.53 | 3160.93 | **7.80** | 28.34 |
| get_resolution | 1.20 | 0.52 | 85.97 | **0.42** | 0.46 |
| cell_to_parent | **1.35** | 2.39 | 161.11 | 2.33 | 2.55 |
| cell_to_children | 0.24 | **0.01** | 0.11 | — | 0.03 |
| compact | 0.69 | **0.01** | 0.17 | — | 0.01 |
| uncompact | 0.59 | **0.01** | 0.27 | — | 0.03 |
| cell_area | 0.16 | **0.00** | 0.02 | — | 0.22 |

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
