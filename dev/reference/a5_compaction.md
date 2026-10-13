# Compact and uncompact sets of cells

`a5_compact()` stores a set of cells as an
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md):
every complete group of siblings is replaced by its parent, repeatedly,
giving the fewest cells for the same set, and the covering records the
resolution the set stands for. `a5_uncompact()` expands coverings back
to their cells at that resolution, or at a finer one. Uncompacting a
compacted set returns the original cells, sorted in curve order and
without duplicates.

## Usage

``` r
a5_compact(cells, resolution = NULL)

a5_uncompact(x, resolution = NULL, simplify = TRUE)
```

## Arguments

- cells:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector. `NA` cells are skipped.

- resolution:

  Integer scalar resolution. For `a5_compact()`, the resolution the
  covering stands for: by default that of the finest cell, and never
  finer than it. For `a5_uncompact()`, the resolution to expand to: by
  default each covering's own, and never coarser than it.

- x:

  An
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector, or an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector treated as one covering (see
  [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)).

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the cells of every covering concatenated in input order.
  If `FALSE`, return an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  with one element per covering, suitable for a list column.

## Value

`a5_compact()`: an
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
of length one. `a5_uncompact()`: an
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector, or an
[a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
when `simplify = FALSE`, with each covering's cells in curve order. A
missing covering contributes no cells (an empty element in the list
form).

## Details

Both work on the index hierarchy (see
[a5_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)),
so the coverage they preserve is the set of index descendants, not a
geometric area.

## Memory

A covering can stand for far more cells than it stores: a country at
resolution 18 is about a billion cells, stored as a few hundred
thousand. `a5_uncompact()` refuses to build more than
`.Machine$integer.max` cells; check with
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
printing first, and prefer the covering functions that work on compacted
sets.

## See also

[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md),
[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
and
[`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md),
which return coverings.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
children <- a5_cell_to_children(cell, resolution = 7)
covering <- a5_compact(children) # stored as the parent
covering
#> <a5_covering[1]>
#> [1] res 7: 16 cells (1 stored)
a5_uncompact(covering)           # the 16 children again
#> <a5_cell[16]>
#>  [1] 6314200000000000 6314600000000000 6314a00000000000 6314e00000000000
#>  [5] 6315200000000000 6315600000000000 6315a00000000000 6315e00000000000
#>  [9] 6316200000000000 6316600000000000 6316a00000000000 6316e00000000000
#> [13] 6317200000000000 6317600000000000 6317a00000000000 6317e00000000000

# expand to a finer resolution
a5_uncompact(a5_compact(cell), resolution = 7)
#> <a5_cell[16]>
#>  [1] 6314200000000000 6314600000000000 6314a00000000000 6314e00000000000
#>  [5] 6315200000000000 6315600000000000 6315a00000000000 6315e00000000000
#>  [9] 6316200000000000 6316600000000000 6316a00000000000 6316e00000000000
#> [13] 6317200000000000 6317600000000000 6317a00000000000 6317e00000000000

# one covering per element, kept apart with simplify = FALSE
disks <- a5_grid_disk(a5_cell_to_children(cell), k = 1)
a5_uncompact(disks, simplify = FALSE)
#> <a5_cell_list[4]>
#> [[1]]
#> <a5_cell[6]>
#> [1] 0cc2800000000000 0cc3800000000000 6314800000000000 6316800000000000
#> [5] 6317800000000000 631a800000000000
#> 
#> [[2]]
#> <a5_cell[6]>
#> [1] 0cbf800000000000 0cc0800000000000 6315800000000000 6316800000000000
#> [5] 63be800000000000 63bf800000000000
#> 
#> [[3]]
#> <a5_cell[6]>
#> [1] 0cc0800000000000 6314800000000000 6315800000000000 6316800000000000
#> [5] 6317800000000000 63bb800000000000
#> 
#> [[4]]
#> <a5_cell[6]>
#> [1] 6314800000000000 6316800000000000 6317800000000000 6318800000000000
#> [5] 6319800000000000 63bb800000000000
#> 
```
