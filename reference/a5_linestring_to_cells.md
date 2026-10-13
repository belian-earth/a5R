# Cells traced by a great-circle linestring

Returns, for each linestring feature, the A5 cells at `resolution` whose
pentagons the great-circle path through its waypoints crosses. Each
path's cells are uncompacted and in order along it, with duplicates
removed first-seen; a `MULTILINESTRING` feature's parts are traced in
order into one path.

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
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector with the paths of every feature concatenated in feature order;
  a cell crossed by several features appears once per feature. If
  `FALSE`, return an
  [a5_cell_list](https://belian-earth.github.io/a5R/reference/a5_cell_list.md)
  with one path per feature, suitable for a list column.

## Value

An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector at `resolution`, or an
[a5_cell_list](https://belian-earth.github.io/a5R/reference/a5_cell_list.md)
when `simplify = FALSE`. A missing or empty geometry contributes no
cells (an empty element in the list form).

## Details

Consecutive waypoints are connected by great-circle arcs (not rhumb
lines or planar segments), so antimeridian-crossing paths work
transparently when written in unwrapped lon/lat.

A path is an ordered sequence, so the result is a vector of cells rather
than an
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md);
use
[`as_a5_covering()`](https://belian-earth.github.io/a5R/reference/a5_covering.md)
to treat the cells a path crosses as a set.

Matrix and `data.frame` inputs are treated as a single linestring; for
multi-feature data, pass an `sf`, `sfc`, wk, or `SpatVector` geometry
instead.

## See also

[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_polygon_to_cells.md),
[`a5_grid_disk()`](https://belian-earth.github.io/a5R/reference/a5_grid_disk.md).

## Examples

``` r
line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
cells <- a5_linestring_to_cells(line, resolution = 6)
cells
#> <a5_cell[6]>
#> [1] 6393800000000000 6394800000000000 6395800000000000 6397800000000000
#> [5] 6396800000000000 63b3800000000000

# One path per feature
lines <- wk::wkt(c(
  "LINESTRING (2.35 48.86, -0.13 51.51)",
  "LINESTRING (2.35 48.86, 4.83 45.76)"
))
paths <- a5_linestring_to_cells(lines, resolution = 6, simplify = FALSE)
lengths(paths)
#> [1] 6 7
```
