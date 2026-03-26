# a5R (development version)

# a5R 0.3.1

* `a5_cell()` now requires hex strings to be exactly 16 characters,
  preventing silent construction of wrong cells from truncated input.
* Improved vignettes covering the new `a5_cell` representation and Arrow
  integration.

# a5R 0.3.0

* `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell (#12).
* `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling `sort()`, `order()`, `unique()`, `duplicated()`, `match()`,
  and `%in%` (#12).
* `a5_cell` gains an `is.na()` method (#12).
* New `a5_cell_from_arrow()` and `a5_cell_to_arrow()` for lossless
  conversion between `a5_cell` and Arrow `uint64` arrays, enabling
  zero-copy Parquet I/O (#12).
* New `a5_u64_to_hex()` and `a5_hex_to_u64()` for explicit conversion
  between `a5_cell` vectors and hex strings.
* `a5_is_cell()` has been renamed to `a5_is_valid()` and now accepts
  both `a5_cell` vectors and character hex strings.
* `a5_cell_distance()` and `a5_cell_area()` gain a `units = NULL`
  option to return plain numeric vectors without `units` class
  overhead.
* New vignettes: `vignette("internal-cell-representation")` and
  `vignette("arrow-parquet")`.

# a5R 0.2.0

* Initial CRAN submission.
