# Spatial parents and children

**\[experimental\]**

## Usage

``` r
a5_cell_to_spatial_parent(cell, resolution = NULL)

a5_cell_to_spatial_children(cell, resolution = NULL, simplify = TRUE)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution, or `NULL` for one step: one
  resolution coarser for `a5_cell_to_spatial_parent()`, one finer for
  `a5_cell_to_spatial_children()`. Children require a resolution at or
  finer than every cell's own.

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

- `a5_cell_to_spatial_parent()`: an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector the same length as `cell`. `NA` where `cell` is `NA`, where
  `resolution` is finer than the cell, or for a resolution-0 cell with
  `resolution = NULL`. A cell at `resolution` is returned unchanged.

- `a5_cell_to_spatial_children()`: an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector, or an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  when `simplify = FALSE`. Each cell's children are in ascending id
  order. An `NA` input contributes no cells.

## Details

`a5_cell_to_spatial_parent()` returns, for each cell, the cell at a
coarser resolution that contains its centre.
`a5_cell_to_spatial_children()` returns, for each cell, the cells at a
finer resolution whose centres lie inside it. These are the
location-based counterparts of
[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
and
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md),
which follow the index and often cross into neighbouring cells (see
[a5_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)).

The two functions define an exact partition. Every fine cell has exactly
one spatial parent, and the spatial children of a coarse cell are
exactly the fine cells whose spatial parent it is, so the spatial
children of cells that tile an area tile it too, with no cell counted
twice. A centre on a shared edge goes to the cell
[`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
assigns it to.

## Spatial parent

The result equals
`a5_lonlat_to_cell(a5_cell_to_lonlat(cell), resolution)`, computed in
one pass without converting the centre to degrees. It costs about as
much as
[`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md).

## Spatial children

Counts vary from cell to cell and average `4^d` for a resolution
difference `d`, or `5 * 4^(d - 1)` from resolution 0. Candidates are the
index descendants of the cell and of its vertex neighbours, filtered by
centre containment.

The result usually equals
`a5_uncompact(a5_polygon_to_cells(cell, resolution), resolution)`. That
route tests centres against a polygon with great-circle edges between
the cell's vertices, while A5 cell edges are slightly curved, so at
large resolution differences it assigns a few edge cells (about 1 in
8,000 at a difference of 6) to a neighbour that
`a5_cell_to_spatial_parent()` would not. `a5_cell_to_spatial_children()`
is also faster and returns one result per input cell.

The result is not compacted, so every cell is at `resolution`, as with
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md).
[`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
on it is lossless
([`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
restores it exactly) and cuts the number of cells sharply at large
resolution differences: to about 9 percent at a difference of 6. Treat
the compacted form as storage only. Compacted cells are index parents,
whose outlines extend beyond the coarse cell (see
[a5_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)),
so uncompact before plotting or any geometric use.

## See also

[a5_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
for parents and children by index,
[`vignette("spatial-hierarchy")`](https://belian-earth.github.io/a5R/dev/articles/spatial-hierarchy.md).

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 18)
a5_cell_to_spatial_parent(cell, resolution = 15)
#> <a5_cell[1]>
#> [1] 6344bba160000000
a5_cell_to_parent(cell, resolution = 15) # may differ
#> <a5_cell[1]>
#> [1] 6344bba160000000

coarse <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
kids <- a5_cell_to_spatial_children(coarse, resolution = 12)
all(a5_cell_to_spatial_parent(kids, resolution = 10) == coarse)
#> [1] TRUE
```
