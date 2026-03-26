# Changelog

## a5R 0.3.1

- [`a5_cell()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  now requires hex strings to be exactly 16 characters, preventing
  silent construction of wrong cells from truncated input.
- Improved vignettes covering the new `a5_cell` representation and Arrow
  integration.

## a5R 0.3.0

- `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling [`sort()`](https://rdrr.io/r/base/sort.html),
  [`order()`](https://rdrr.io/r/base/order.html),
  [`unique()`](https://rdrr.io/r/base/unique.html),
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html),
  [`match()`](https://rdrr.io/r/base/match.html), and `%in%`
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- `a5_cell` gains an [`is.na()`](https://rdrr.io/r/base/NA.html) method
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- New
  [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
  and
  [`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
  for lossless conversion between `a5_cell` and Arrow `uint64` arrays,
  enabling zero-copy Parquet I/O
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- New
  [`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/reference/a5_u64_to_hex.md)
  and
  [`a5_hex_to_u64()`](https://belian-earth.github.io/a5R/reference/a5_u64_to_hex.md)
  for explicit conversion between `a5_cell` vectors and hex strings.
- `a5_is_cell()` has been renamed to
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  and now accepts both `a5_cell` vectors and character hex strings.
- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/reference/a5_cell_distance.md)
  and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/reference/a5_cell_area.md)
  gain a `units = NULL` option to return plain numeric vectors without
  `units` class overhead.
- New vignettes:
  [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/articles/internal-cell-representation.md)
  and
  [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/articles/arrow-parquet.md).

## a5R 0.2.0

CRAN release: 2026-03-16

- Initial CRAN submission.
