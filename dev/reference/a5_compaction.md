# Compact and uncompact sets of cells

`a5_compact()` replaces every complete set of siblings with their common
parent, repeatedly, giving the fewest cells that cover the same set.
`a5_uncompact()` expands each cell to its descendants at a target
resolution. Uncompacting a compacted set to the original resolution
returns the original cells.

## Usage

``` r
a5_compact(cells)

a5_uncompact(cells, resolution)
```

## Arguments

- cells:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution (0–30), at or finer than every cell's
  own resolution.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector: mixed resolutions for `a5_compact()`, all at `resolution` for
`a5_uncompact()`.

## Details

Both work on the index hierarchy (see
[a5_hierarchy](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)),
so the coverage they preserve is the set of index descendants, not a
geometric area.

## See also

[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
and
[`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md),
which return compacted sets.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
children <- a5_cell_to_children(cell, resolution = 7)
a5_compact(children) # back to the parent
#> <a5_cell[1]>
#> [1] 633e000000000000
a5_uncompact(cell, resolution = 7)
#> <a5_cell[16]>
#>  [1] 633c200000000000 633c600000000000 633ca00000000000 633ce00000000000
#>  [5] 633d200000000000 633d600000000000 633da00000000000 633de00000000000
#>  [9] 633e200000000000 633e600000000000 633ea00000000000 633ee00000000000
#> [13] 633f200000000000 633f600000000000 633fa00000000000 633fe00000000000

# the round trip restores the original cells
identical(vctrs::vec_sort(a5_uncompact(a5_compact(children), 7)),
          vctrs::vec_sort(children))
#> [1] TRUE
```
