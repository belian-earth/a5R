# Get cell boundary vertices as flat coordinate vectors

Returns the boundary vertices of every cell in one pair of coordinate
vectors, with a vector of per-cell vertex counts. This skips building a
geometry for each cell, so it suits drawing many cells at once, for
example as a single
[`grid::polygonGrob()`](https://rdrr.io/r/grid/grid.polygon.html) with
`id.lengths = lengths`.

## Usage

``` r
a5_cell_to_boundary_xy(cell, closed_ring = FALSE, segments = NULL, closed)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- closed_ring:

  Logical scalar; if `TRUE` each ring repeats its first vertex at the
  end. Defaults to `FALSE`, unlike
  [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md),
  since polygon drawing closes rings itself.

- segments:

  Integer scalar or `NULL`. Number of segments per cell edge. A5 cell
  edges are slightly curved on the sphere: a single segment between two
  vertices strays from the true edge by up to about 450 m at resolution
  6, 25 m at resolution 8 and 1.5 m at resolution 10. The error falls
  with the square of the number of segments. `NULL` uses the A5 default
  of `max(1, 2^(6 - resolution))`, so at resolution 6 and finer each
  edge is a single segment. Pass a larger value when the polygons are
  used for spatial tests rather than display.

- closed:

  Deprecated: renamed `closed_ring`, as in the other A5 libraries.

## Value

A list with three elements:

- `x`: double vector of longitudes, every cell's vertices in turn.

- `y`: double vector of latitudes, aligned with `x`.

- `lengths`: integer vector with the number of vertices of each cell,
  the same length as `cell`. An `NA` cell has length 0.

## Details

The vertices and their order are those of
[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md).
Longitudes within a ring are continuous, as in the other A5 libraries: a
ring that crosses the antimeridian continues past 180 or -180 instead of
jumping, so `x` can fall outside \[-180, 180\]. Shift or split such
rings before drawing them on a map that wraps at the antimeridian. A
ring around a pole cannot be drawn as a simple polygon in longitude and
latitude.

## See also

[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
for polygon geometries.

## Examples

``` r
cells <- a5_lonlat_to_cell(c(-3.19, -3.10), c(55.95, 55.90), resolution = 9)
xy <- a5_cell_to_boundary_xy(cells)
xy$lengths
#> [1] 5 5

# one grob for all cells
grob <- grid::polygonGrob(
  xy$x, xy$y,
  id.lengths = xy$lengths,
  default.units = "native"
)
```
