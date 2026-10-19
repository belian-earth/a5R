# Supercells and subcells: parents and children by location

`a5_cell_to_supercell()` returns, for each cell, the cell at a coarser
resolution that contains its centre. `a5_cell_to_subcells()` returns,
for each cell, the cells at a finer resolution whose centres lie inside
it, as an
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md).
These are the location-based counterparts of
[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_hierarchy.md)
and
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/reference/a5_hierarchy.md),
which follow the index and often cross into neighbouring cells (see
[a5_hierarchy](https://belian-earth.github.io/a5R/reference/a5_hierarchy.md)).

## Usage

``` r
a5_cell_to_supercell(cell, resolution = NULL)

a5_cell_to_subcells(cell, resolution = NULL)
```

## Arguments

- cell:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution, or `NULL` for one step: one
  resolution coarser for `a5_cell_to_supercell()`, one finer for
  `a5_cell_to_subcells()`. Subcells require a resolution at or finer
  than every cell's own.

## Value

- `a5_cell_to_supercell()`: an
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector the same length as `cell`. `NA` where `cell` is `NA`, where
  `resolution` is finer than the cell, or for a resolution-0 cell with
  `resolution = NULL`. A cell at `resolution` is returned unchanged.

- `a5_cell_to_subcells()`: an
  [a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md)
  vector the same length as `cell`. `NA` where `cell` is `NA`.

## Details

The two functions define an exact partition. Every fine cell has exactly
one supercell at each coarser resolution, and the subcells of a coarse
cell are exactly the fine cells whose supercell it is, so the subcells
of cells that tile an area tile it too, with no cell counted twice. A
centre on a shared edge goes to the cell
[`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_coordinates.md)
assigns it to. Aggregating fine values by supercell therefore attributes
each value to the coarse cell it lies in.

## Supercell

The result equals
`a5_lonlat_to_cell(a5_cell_to_lonlat(cell), resolution)`, computed
without converting the centre to degrees. It takes about half the time
of
[`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_coordinates.md),
but far longer than
[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_hierarchy.md),
which is a bit operation.

## Subcells

Counts vary from cell to cell and average `4^d` for a resolution
difference `d`, or `5 * 4^(d - 1)` from resolution 0. The covering is
compacted, so it stores far fewer cells than it stands for at large
differences; use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md)
for the cells, and never draw the stored cells, which are index parents
whose outlines extend beyond the coarse cell. Resolution 30 covers only
part of the globe, so a cell whose subcells reach past it has all its
subcells given at resolution 29.

## See also

[a5_hierarchy](https://belian-earth.github.io/a5R/reference/a5_hierarchy.md)
for parents and children by index,
[`vignette("spatial-hierarchy")`](https://belian-earth.github.io/a5R/articles/spatial-hierarchy.md).

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 18)
a5_cell_to_supercell(cell, resolution = 15)
#> <a5_cell[1]>
#> [1] 63bb93f8a0000000
a5_cell_to_parent(cell, parent_resolution = 15) # may differ
#> <a5_cell[1]>
#> [1] 63bb93f8a0000000

coarse <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
sub <- a5_cell_to_subcells(coarse, resolution = 12)
sub
#> <a5_covering[1]>
#> [1] res 12: 14 cells (11 stored)
kids <- a5_uncompact(sub)
all(a5_cell_to_supercell(kids, resolution = 10) == coarse)
#> [1] TRUE
```
