# Test coverings

`a5_contains()` tests whether each cell is in a covering, and
`a5_overlaps()` whether two coverings share any cell. Both work on the
compacted cells, without expanding them, and element by element,
recycling a length-one argument.

## Usage

``` r
a5_contains(x, cell)

a5_overlaps(x, y)
```

## Arguments

- x:

  An
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector, or an object
  [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  accepts.

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector, each at the resolution of its covering.

- y:

  An
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector, at the same resolution as `x`.

## Value

A logical vector of the common size of the inputs. `NA` where either
input is `NA`.

## Details

`a5_contains()` is a point-in-polygon test once the point is indexed at
the covering's resolution:
`a5_contains(covering, a5_lonlat_to_cell(lon, lat, a5_covering_resolution(covering)))`.
The cell must be at the covering's resolution, or it is an error: A5
cells do not nest geometrically, so a finer cell is not guaranteed to
lie inside the coarser cell that holds it in the index. An empty
covering contains no cell.

## See also

[a5_set_operations](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md).

## Examples

``` r
poly <- wk::wkt("POLYGON ((-3.4 55.85, -3 55.85, -3 56.05, -3.4 56.05, -3.4 55.85))")
edinburgh <- a5_polygon_to_cells(poly, resolution = 12)

# point in polygon, at the covering's resolution
points <- a5_lonlat_to_cell(c(-3.19, -4.25), c(55.95, 55.86), resolution = 12)
a5_contains(edinburgh, points)
#> [1]  TRUE FALSE

cap <- a5_spherical_cap(points, radius = 5000)
a5_overlaps(edinburgh, cap)
#> [1]  TRUE FALSE
```
