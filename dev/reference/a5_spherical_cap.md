# Cells within a great-circle radius

Returns, for each centre cell, the cells whose centres fall within a
great-circle distance of its centre, as an
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md).

## Usage

``` r
a5_spherical_cap(cell, radius)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector of centre cells.

- radius:

  Numeric scalar, great-circle radius in metres.

## Value

An
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vector the same length as `cell`, at the resolution of each centre cell.
`NA` where `cell` is `NA`. Use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
for the cells.

## See also

[`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
for hop-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
cap <- a5_spherical_cap(cell, radius = 1000)
cap
#> <a5_covering[1]>
#> [1] res 8: 1 cell (1 stored)
a5_uncompact(cap)
#> <a5_cell[1]>
#> [1] 63bb980000000000
```
