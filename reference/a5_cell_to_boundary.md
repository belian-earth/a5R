# Get cell boundary polygons

Returns the boundary of each cell as a
[`wk::wkt()`](https://paleolimbot.github.io/wk/reference/wkt.html) or
[`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html)
polygon geometry. Boundaries are pentagonal polygons on the WGS 84
ellipsoid.

## Usage

``` r
a5_cell_to_boundary(
  cell,
  format = c("wkb", "wkt"),
  closed = TRUE,
  segments = NULL
)
```

## Arguments

- cell:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector.

- format:

  Character scalar, either `"wkb"` (default) or `"wkt"`.

- closed:

  Logical scalar; if `TRUE` (default) the ring is closed (first vertex
  repeated at end).

- segments:

  Integer scalar or `NULL`. Number of interpolation segments per edge
  for geodesic accuracy. `NULL` uses the default (straight edges).

## Value

A `wk_wkt` or `wk_wkb` vector of polygon geometries with
[`wk::wk_crs_longlat()`](https://paleolimbot.github.io/wk/reference/wk_crs_inherit.html)
CRS.

## See also

[`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_lonlat.md)
for cell centroids.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_to_boundary(cell)
#> <wk_wkb[1] with CRS=OGC:CRS84>
#> [1] <POLYGON ((-4.490769 56.63193, -4.575103 55.93184, -4.654266 55.23196, -3.592316 55.41531, -2.521971 55.5901, -2.031558 56.23106...>
a5_cell_to_boundary(cell, format = "wkt")
#> <wk_wkt[1] with CRS=OGC:CRS84>
#> [1] POLYGON ((-4.490769 56.63193, -4.575103 55.93184, -4.654266 55.23196, -3.592316 55.41531, -2.521971 55.5901, -2.031558 56.23106...
```
