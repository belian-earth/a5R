# Range of descendant cell ids

Returns the smallest and largest descendant of each cell at a finer
resolution, without enumerating the descendants. Because the A5 index
encodes position along a Hilbert curve with a cell's descendants sharing
its leading bits, the descendants of a cell at any resolution up to 29
occupy a contiguous range of ids among all cells at that resolution:
every cell at `resolution` whose id lies between `lo` and `hi` inclusive
is a descendant, and no descendant lies outside. This makes
`BETWEEN lo AND hi` an exact filter on a store of `resolution` cells
sorted by id. Not every integer in the range is a valid cell, and cells
of other resolutions may fall inside it.

## Usage

``` r
a5_cell_children_range(cell, resolution)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution from 0 to 29, at or finer than every
  cell's own resolution.

## Value

A data frame with
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
columns `lo` and `hi`, one row per input cell. `NA` where `cell` is
`NA`.

## Details

Resolution 30 is refused because the guarantee does not hold there. The
index has no room for the usual face bits at that resolution, so faces
use three different bit layouts whose id ranges overlap numerically, and
a range can contain valid resolution-30 cells from another face.
Eighteen of the sixty faces cannot be encoded at resolution 30 at all;
the upstream library falls back to resolution 29 for them. Use
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md)
if you need resolution-30 descendants.

## See also

[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md),
[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
for exact 64-bit ids to pass to SQL.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
rng <- a5_cell_children_range(cell, resolution = 8)
children <- vctrs::vec_sort(a5_cell_to_children(cell, resolution = 8))
identical(rng$lo, children[1])
#> [1] TRUE
identical(rng$hi, children[length(children)])
#> [1] TRUE
```
