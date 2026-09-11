# Cells within a great-circle radius

Returns all cells whose centres fall within a great-circle distance of
each input cell's centre.

## Usage

``` r
a5_spherical_cap(cell, radius, simplify = TRUE)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector of centre cells.

- radius:

  Numeric scalar, great-circle radius in metres.

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the caps of every input concatenated in input order; cells
  shared by several caps appear once per cap. If `FALSE`, return an
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

[`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
for hop-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
a5_spherical_cap(cell, radius = 1000)
#> <a5_cell[1]>
#> [1] 6344b80000000000

cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 8)
a5_spherical_cap(cells, radius = 1000, simplify = FALSE) # list of 2
#> <a5_cell_list[2]>
#> [[1]]
#> <a5_cell[1]>
#> [1] 6344b80000000000
#> 
#> [[2]]
#> <a5_cell[1]>
#> [1] 4f05d80000000000
#> 
```
