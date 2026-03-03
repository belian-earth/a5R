# Cells within k hops of a cell

Returns all cells reachable within `k` edge hops of a centre cell,
including the centre cell itself.

## Usage

``` r
a5_grid_disk(cell, k, vertex = FALSE)
```

## Arguments

- cell:

  A single
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  value.

- k:

  Integer scalar, number of hops.

- vertex:

  Logical scalar. If `FALSE` (default), only edge-sharing neighbours
  (4-connected) are traversed. If `TRUE`, vertex-sharing neighbours are
  included (8-connected).

## Value

A compacted
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector.

## See also

[`a5_spherical_cap()`](https://belian-earth.github.io/a5R/reference/a5_spherical_cap.md)
for distance-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
a5_grid_disk(cell, k = 1)
#> <a5_cell[6]>
#> [1] 633df80000000000 6341380000000000 6341480000000000 6344980000000000
#> [5] 6344a80000000000 6344b80000000000
```
