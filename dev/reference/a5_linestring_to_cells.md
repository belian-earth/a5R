# Cells traced by a great-circle linestring

Returns the A5 cells at `resolution` whose pentagons are intersected by
the great-circle polyline connecting the supplied waypoints. Output is
uncompacted, in discovery order along the path, with duplicates removed
first-seen. Multi-feature inputs (a `MULTILINESTRING` or an `sfc` of
multiple linestrings) are handled natively: per-feature cell sequences
are concatenated in feature order with first-seen deduplication.

## Usage

``` r
a5_linestring_to_cells(x, resolution)
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

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector at `resolution`.

## Details

Consecutive waypoints are connected by great-circle arcs (not rhumb
lines or planar segments), so antimeridian-crossing paths work
transparently when written in unwrapped lon/lat.

Matrix and `data.frame` inputs are treated as a single linestring; for
multi-feature data, pass an `sf`, `sfc`, wk, or `SpatVector` geometry
instead.

## See also

[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md),
[`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md).

## Examples

``` r
line <- wk::wkt("LINESTRING (2.35 48.86, -0.13 51.51)")
cells <- a5_linestring_to_cells(line, resolution = 6)
length(cells)
#> [1] 6
```
