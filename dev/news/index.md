# Changelog

## a5R (development version)

## a5R 0.3.0

- Replaced internal cell representation: cell IDs are now stored as 8
  parallel raw byte vectors instead of hex strings, reducing memory
  usage from ~80 bytes/cell to 8 bytes/cell.
- Added lossless Arrow `uint64` conversion for zero-copy Parquet I/O.
- Added `vec_proxy_compare()` and `vec_proxy_order()` methods for
  `a5_cell`, enabling [`sort()`](https://rdrr.io/r/base/sort.html),
  [`order()`](https://rdrr.io/r/base/order.html),
  [`unique()`](https://rdrr.io/r/base/unique.html),
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html),
  [`match()`](https://rdrr.io/r/base/match.html), and `%in%`.
- Added [`is.na()`](https://rdrr.io/r/base/NA.html) method for
  `a5_cell`.
- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_area.md)
  gain `units = NULL` option to return plain numeric vectors (in metres
  / m²) without `units` class overhead.

## a5R 0.2.0

CRAN release: 2026-03-16

- Initial CRAN submission.
