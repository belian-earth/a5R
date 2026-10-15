# Index parents and children

`a5_cell_to_parent()` returns the ancestor of each cell at a coarser
resolution. `a5_cell_to_children()` returns the descendants of each cell
at a finer resolution: 4 per resolution step, or 5 from resolution 0.
Both follow the cell index, so they are cheap bit operations.

## Usage

``` r
a5_cell_to_parent(cell, resolution = NULL)

a5_cell_to_children(cell, resolution = NULL, simplify = TRUE)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution, or `NULL` for one step: the
  immediate parent for `a5_cell_to_parent()`, the immediate children for
  `a5_cell_to_children()`. For `a5_cell_to_parent()` it must not be
  finer than any cell's resolution.

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the children of every input concatenated in input order;
  which child came from which parent is not recorded. If `FALSE`, return
  an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md):
  a [`vctrs::list_of()`](https://vctrs.r-lib.org/reference/list_of.html)
  of
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vectors with one element per input, suitable for a list column.

## Value

- `a5_cell_to_parent()`: an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector the same length as `cell`.

- `a5_cell_to_children()`: an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector, or an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  when `simplify = FALSE`. An `NA` input contributes no cells (an empty
  element in the list form).

## Index hierarchy is not spatially nested

A5 parents and children are defined by the cell index, not by geometry.
A cell's index children do not tile it: their union overlaps the
parent's neighbours. Measured over random cells, the index parent is not
the coarse cell containing a fine cell's centre for about half of fine
cells one resolution apart, falling to about 35 percent at four or more
resolutions apart. Use these functions for operations on ids
(compaction, id ranges, Hilbert ordering) and
[a5_spatial_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
when cells must nest by location.

## See also

[a5_spatial_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
for parents and children by location,
[`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
for one child at a time,
[`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
for the id range of all descendants,
[`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md).

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
a5_cell_to_parent(cell)
#> <a5_cell[1]>
#> [1] 63bb960000000000
a5_cell_to_parent(cell, resolution = 5)
#> <a5_cell[1]>
#> [1] 63ba000000000000

a5_cell_to_children(cell)
#> <a5_cell[4]>
#> [1] 63bb942000000000 63bb946000000000 63bb94a000000000 63bb94e000000000
cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
a5_cell_to_children(cells, resolution = 7)                   # 32 cells
#> <a5_cell[32]>
#>  [1] 6314200000000000 6314600000000000 6314a00000000000 6314e00000000000
#>  [5] 6315200000000000 6315600000000000 6315a00000000000 6315e00000000000
#>  [9] 6316200000000000 6316600000000000 6316a00000000000 6316e00000000000
#> [13] 6317200000000000 6317600000000000 6317a00000000000 6317e00000000000
#> [17] 4f08200000000000 4f08600000000000 4f08a00000000000 4f08e00000000000
#> [21] 4f09200000000000 4f09600000000000 4f09a00000000000 4f09e00000000000
#> [25] 4f0a200000000000 4f0a600000000000 4f0aa00000000000 4f0ae00000000000
#> [29] 4f0b200000000000 4f0b600000000000 4f0ba00000000000 4f0be00000000000
a5_cell_to_children(cells, resolution = 7, simplify = FALSE) # list of 2
#> <a5_cell_list[2]>
#> [[1]]
#> <a5_cell[16]>
#>  [1] 6314200000000000 6314600000000000 6314a00000000000 6314e00000000000
#>  [5] 6315200000000000 6315600000000000 6315a00000000000 6315e00000000000
#>  [9] 6316200000000000 6316600000000000 6316a00000000000 6316e00000000000
#> [13] 6317200000000000 6317600000000000 6317a00000000000 6317e00000000000
#> 
#> [[2]]
#> <a5_cell[16]>
#>  [1] 4f08200000000000 4f08600000000000 4f08a00000000000 4f08e00000000000
#>  [5] 4f09200000000000 4f09600000000000 4f09a00000000000 4f09e00000000000
#>  [9] 4f0a200000000000 4f0a600000000000 4f0aa00000000000 4f0ae00000000000
#> [13] 4f0b200000000000 4f0b600000000000 4f0ba00000000000 4f0be00000000000
#> 

# children map back to their parent
all(a5_cell_to_parent(a5_cell_to_children(cell, 12), 10) == cell)
#> [1] TRUE
```
