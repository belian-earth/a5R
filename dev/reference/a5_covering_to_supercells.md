# Supercells of a covering

`a5_covering_to_supercells()` gives, for each covering, the cells at a
coarser `resolution` that contain the centre of at least one of its
cells, such as the partitions of a store that hold an area's data. It
matches `a5_cell_to_supercell(a5_uncompact(x), resolution)` without
duplicates, but never builds the covering's cells.

## Usage

``` r
a5_covering_to_supercells(x, resolution)
```

## Arguments

- x:

  An
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector.

- resolution:

  Integer scalar target resolution, at or coarser than each covering's
  resolution.

## Value

An
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vector at `resolution`, the same length as `x`. `NA` where `x` is `NA`.

## See also

[`a5_cell_to_supercell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)

## Examples

``` r
area <- a5_polygon_to_cells(
  wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))"),
  resolution = 14
)
a5_uncompact(a5_covering_to_supercells(area, 6))
#> <a5_cell[2]>
#> [1] 63bb800000000000 63be800000000000
```
