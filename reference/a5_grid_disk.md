# Cells within k hops of a cell

Returns, for each centre cell, the cells reachable within `k` hops,
including the centre cell itself, as an
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md).
`a5_grid_disk()` steps between cells that share an edge;
`a5_grid_disk_vertex()` also steps between cells that share only a
vertex, so it reaches more cells for the same `k`.

## Usage

``` r
a5_grid_disk(cell, k)

a5_grid_disk_vertex(cell, k)
```

## Arguments

- cell:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector of centre cells.

- k:

  Non-negative integer scalar, number of hops.

## Value

An
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md)
vector the same length as `cell`, at the resolution of each centre cell.
`NA` where `cell` is `NA`. Use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md)
for the cells.

## See also

[`a5_spherical_cap()`](https://belian-earth.github.io/a5R/reference/a5_spherical_cap.md)
for distance-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
disk <- a5_grid_disk(cell, k = 1)
disk
#> <a5_covering[1]>
#> [1] res 8: 6 cells (6 stored)
a5_uncompact(disk)
#> <a5_cell[6]>
#> [1] 6316080000000000 63bb880000000000 63bb980000000000 63bba80000000000
#> [5] 63beb80000000000 63bec80000000000
a5_grid_disk_vertex(cell, k = 1)
#> <a5_covering[1]>
#> [1] res 8: 8 cells (8 stored)

cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
a5_grid_disk(cells, k = 2) # one covering per cell
#> <a5_covering[2]>
#> [1] res 5: 17 cells (14 stored) res 5: 17 cells (11 stored)
```
