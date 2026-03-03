# Cells within a great-circle radius

Returns all cells whose centres fall within a great-circle distance of a
given cell's centre.

## Usage

``` r
a5_spherical_cap(cell, radius)
```

## Arguments

- cell:

  A single
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  value.

- radius:

  Numeric scalar, great-circle radius in metres.

## Value

A compacted
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector.

## See also

[`a5_grid_disk()`](https://belian-earth.github.io/a5R/reference/a5_grid_disk.md)
for hop-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
a5_spherical_cap(cell, radius = 1000)
#> <a5_cell[1]>
#> [1] 6344b80000000000
```
