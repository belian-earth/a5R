# Cells within k hops of a cell

Returns all cells reachable within `k` edge hops of a centre cell,
including the centre cell itself.

## Usage

``` r
a5_grid_disk(cell, k, vertex = FALSE, simplify = TRUE)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector of centre cells.

- k:

  Integer scalar, number of hops.

- vertex:

  Logical scalar. If `FALSE` (default), only edge-sharing neighbours
  (4-connected) are traversed. If `TRUE`, vertex-sharing neighbours are
  included (8-connected).

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the disks of every input concatenated in input order;
  cells shared by several disks appear once per disk. If `FALSE`, return
  an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md):
  a [`vctrs::list_of()`](https://vctrs.r-lib.org/reference/list_of.html)
  of
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vectors with one element per input, suitable for a list column.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector, or an
[a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
when `simplify = FALSE`. An `NA` input contributes no cells (an empty
element in the list form).

## See also

[`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
for distance-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
a5_grid_disk(cell, k = 1)
#> <a5_cell[6]>
#> [1] 633df80000000000 6341380000000000 6341480000000000 6344980000000000
#> [5] 6344a80000000000 6344b80000000000

cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
a5_grid_disk(cells, k = 1)                   # both disks, one vector
#> <a5_cell[9]>
#> [1] 0c42000000000000 0caa000000000000 6336000000000000 633e000000000000
#> [5] 6342000000000000 6346000000000000 4f08000000000000 4f22000000000000
#> [9] 56fa000000000000
a5_grid_disk(cells, k = 1, simplify = FALSE) # list of 2
#> <a5_cell_list[2]>
#> [[1]]
#> <a5_cell[6]>
#> [1] 0c42000000000000 0caa000000000000 6336000000000000 633e000000000000
#> [5] 6342000000000000 6346000000000000
#> 
#> [[2]]
#> <a5_cell[3]>
#> [1] 4f08000000000000 4f22000000000000 56fa000000000000
#> 
```
