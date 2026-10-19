# A5 covering vectors

A covering is a set of A5 cells at one resolution, standing for an area
of the globe, possibly in disjoint parts: the cells of a polygon, a disk
or a cap. It is stored compacted. Complete groups of sibling cells are
replaced by their parent, so the stored cells have mixed resolutions,
and a trailing *compaction marker* records the resolution they stand
for. An `a5_covering` vector holds one covering per element, so it fits
in a data frame column, with one covering per feature or per centre
cell.

## Usage

``` r
as_a5_covering(x, ...)

# S3 method for class 'a5_covering'
as_a5_covering(x, ...)

# S3 method for class 'a5_cell'
as_a5_covering(x, resolution = NULL, ...)

# S3 method for class 'a5_cell_list'
as_a5_covering(x, resolution = NULL, ...)

# S3 method for class 'list'
as_a5_covering(x, resolution = NULL, ...)

is_a5_covering(x)

a5_covering_resolution(x)
```

## Arguments

- x:

  For `as_a5_covering()`: an
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector (one covering), an
  [a5_cell_list](https://belian-earth.github.io/a5R/reference/a5_cell_list.md)
  (one covering per element), or a list of
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vectors or of raw vectors of little-endian 64-bit values, as stored by
  other A5 libraries. `NULL` list elements are missing coverings. For
  `a5_covering_resolution()` and `is_a5_covering()`: any object.

- ...:

  Unused.

- resolution:

  Integer scalar resolution the coverings stand for, or `NULL` (the
  default) for the resolution of each input's finest cell. No cell may
  be finer than `resolution`. Ignored for raw input that carries a
  compaction marker.

## Value

`as_a5_covering()`: an `a5_covering` vector. `a5_covering_resolution()`:
an integer vector, `NA` for a missing covering and -1 for an empty one
without a recorded resolution. `is_a5_covering()`: a logical scalar.

## Details

[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_polygon_to_cells.md),
[`a5_grid_disk()`](https://belian-earth.github.io/a5R/reference/a5_grid_disk.md),
[`a5_spherical_cap()`](https://belian-earth.github.io/a5R/reference/a5_spherical_cap.md)
and
[`a5_compact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md)
return coverings. `as_a5_covering()` builds them from cells or from raw
64-bit values, sorting and compacting them as needed.
`a5_covering_resolution()` returns the resolution each covering stands
for, and
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md)
expands coverings to their cells.

## Working with coverings

Use coverings through a5R functions where one fits. The stored cells are
index parents (see
[a5_hierarchy](https://belian-earth.github.io/a5R/reference/a5_hierarchy.md)):
their outlines do not nest geometrically, so drawing them shows overlaps
and gaps. Uncompact a covering before plotting or joining it to data
keyed by cell. For index range queries,
[`a5_covering_stored()`](https://belian-earth.github.io/a5R/reference/a5_covering_stored.md)
returns the stored cells.

[`length()`](https://rdrr.io/r/base/length.html) counts coverings, not
cells. `x[i]` and `x[[i]]` both return coverings, and
[`c()`](https://rdrr.io/r/base/c.html) concatenates them. Two coverings
of the same cells compare equal with `==`, because a5R always stores a
covering in the same sorted, compacted form. A missing covering is `NA`,
for example the disk around an `NA` cell; an empty covering (no cells)
is not missing.

Coverings are stored with the compaction marker, as in the other A5
libraries, so
[`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)
writes them to a `list<uint64>` column that DuckDB, Python and
JavaScript read without losing the resolution.

## See also

[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md),
[`a5_is_valid()`](https://belian-earth.github.io/a5R/reference/a5_is_valid.md),
[`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md).

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
disk <- a5_grid_disk(cell, k = 3)
disk
#> <a5_covering[1]>
#> [1] res 8: 33 cells (18 stored)
a5_covering_resolution(disk)
#> [1] 8

# from cells: complete sibling groups are stored as their parent
kids <- a5_cell_to_children(cell, child_resolution = 10)
as_a5_covering(kids)
#> <a5_covering[1]>
#> [1] res 10: 16 cells (1 stored)
as_a5_covering(kids[-1])
#> <a5_covering[1]>
#> [1] res 10: 15 cells (6 stored)
```
