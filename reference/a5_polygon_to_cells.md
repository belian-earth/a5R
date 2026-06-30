# Cells whose centres lie inside a polygon

Returns A5 cells at `resolution` whose centres fall inside the polygon.
Multi-feature inputs (a `MULTIPOLYGON`, an `sfc` of multiple polygons,
or a `POLYGON` with holes) are handled natively: per polygon part, the
outer ring and its holes are converted together with hole interiors
excluded, then the results are unioned across parts. The final cell set
is compacted; use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_uncompact.md)
to expand to a uniform-resolution grid.

## Usage

``` r
a5_polygon_to_cells(x, resolution)
```

## Arguments

- x:

  A polygon-like geometry. One of:

  - Any geometry handleable by
    [`wk::wk_handle()`](https://paleolimbot.github.io/wk/reference/wk_handle.html)
    (e.g.
    [`wk::wkt()`](https://paleolimbot.github.io/wk/reference/wkt.html),
    [`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html),
    [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html),
    `sf`, `sfc`) containing one or more `POLYGON` / `MULTIPOLYGON`
    features.

  - A `SpatVector` of polygons (requires the `terra` package).

  - A two-column numeric matrix (`cbind(lon, lat)`) of vertices,
    interpreted as a single outer ring.

  - A `data.frame` with columns `lon` and `lat`, interpreted as a single
    outer ring.

- resolution:

  Integer scalar target resolution (0-30).

## Value

An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector at or coarser than `resolution`.

## Details

Membership is determined by **centre-point containment**: a cell is
included if its centroid lies inside the polygon, with hole interiors
excluded.

Coordinates must be WGS 84 longitude/latitude in degrees. Rings are
closed automatically; a trailing duplicate vertex is dropped if present.

Where no A5 cell centroids at the specified `resolution` fall within the
geometry, an empty `a5_cell` vector is returned.

Matrix and `data.frame` inputs are treated as a single ring; for
multi-feature data or polygons with holes, pass an `sf`, `sfc`, wk, or
`SpatVector` geometry instead.

## See also

[`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_linestring_to_cells.md),
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_uncompact.md).

## Examples

``` r
poly <- wk::wkt(
  "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))"
)
cells <- a5_polygon_to_cells(poly, resolution = 8)
length(cells)
#> [1] 0
```
