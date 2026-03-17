# a5R 0.3.0

* `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell (#12).
* `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling `sort()`, `order()`, `unique()`, `duplicated()`, `match()`,
  and `%in%` (#12).
* `a5_cell` gains an `is.na()` method (#12).
* `a5_cell` gains lossless Arrow `uint64` conversion for zero-copy
  Parquet I/O (#12).
* `a5_cell_distance()` and `a5_cell_area()` gain a `units = NULL`
  option to return plain numeric vectors without `units` class
  overhead.

# a5R 0.2.0

* Initial CRAN submission.
