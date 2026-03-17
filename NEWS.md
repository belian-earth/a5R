# a5R (development version)

# a5R 0.3.0

* Replaced internal cell representation: cell IDs are now stored as 8 parallel
  raw byte vectors instead of hex strings, reducing memory usage from ~80
  bytes/cell to 8 bytes/cell.
* Added lossless Arrow `uint64` conversion for zero-copy Parquet I/O.
* Added `vec_proxy_compare()` and `vec_proxy_order()` methods for `a5_cell`,
  enabling `sort()`, `order()`, `unique()`, `duplicated()`, `match()`, and
  `%in%`.
* Added `is.na()` method for `a5_cell`.
* `a5_cell_distance()` and `a5_cell_area()` gain `units = NULL` option to
  return plain numeric vectors (in metres / m²) without `units` class overhead.

# a5R 0.2.0

* Initial CRAN submission.
