# Deprecated: use [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md)

`a5_linestring_to_cells()` was renamed
[`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md)
to match `line_string_to_cells()` in the other A5 libraries. The old
name still works but warns.

## Usage

``` r
a5_linestring_to_cells(x, resolution, simplify = TRUE)
```

## Arguments

- x:

  A linestring-like geometry. One of:

  - Any geometry handleable by
    [`wk::wk_handle()`](https://paleolimbot.github.io/wk/reference/wk_handle.html)
    containing one or more `LINESTRING` / `MULTILINESTRING` features.

  - A `SpatVector` of linestrings (requires the `terra` package).

  - A two-column numeric matrix (`cbind(lon, lat)`) of waypoints.

  - A `data.frame` with columns `lon` and `lat`.

- resolution:

  Integer scalar target resolution (0–30).

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the paths of every feature concatenated in feature order;
  a cell crossed by several features appears once per feature. If
  `FALSE`, return an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  with one path per feature, suitable for a list column.

## Value

As
[`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md).
