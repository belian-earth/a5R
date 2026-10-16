# Stored cells of a covering

Returns the cells a covering stores: its compacted cells, which have
mixed resolutions, in curve order and without the compaction marker. Use
them for index range queries. Each stored cell's descendants at the
covering's resolution form one contiguous id range, given by
[`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md),
so a covering is the union of those ranges.

## Usage

``` r
a5_covering_stored(x, simplify = TRUE)
```

## Arguments

- x:

  An
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector, or anything
  [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  accepts.

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the stored cells of every covering in turn. If `FALSE`,
  return an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  with one element per covering; a missing covering gives an empty
  element.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector, or an
[a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
if `simplify = FALSE`.

## Details

The stored cells are index parents, not geometric ones: their outlines
do not nest, so do not draw them or use them as an area. Use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
for the cells a covering stands for.

## See also

[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
for the cells at the covering's resolution,
[`a5_covering_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md),
[`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md).

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
disk <- a5_grid_disk(cell, k = 3)
stored <- a5_covering_stored(disk)
a5_get_resolution(stored)
#>  [1] 8 8 8 8 8 7 8 8 8 8 7 7 8 8 8 8 7 7

# one id range per stored cell, at the covering's resolution
a5_cell_children_range(stored, child_resolution = a5_covering_resolution(disk))
#>                  lo               hi
#> 1  6315880000000000 6315880000000000
#> 2  6315980000000000 6315980000000000
#> 3  6315d80000000000 6315d80000000000
#> 4  6315e80000000000 6315e80000000000
#> 5  6315f80000000000 6315f80000000000
#> 6  6316080000000000 6316380000000000
#> 7  6316580000000000 6316580000000000
#> 8  6316680000000000 6316680000000000
#> 9  6316780000000000 6316780000000000
#> 10 63bb280000000000 63bb280000000000
#> 11 63bb480000000000 63bb780000000000
#> 12 63bb880000000000 63bbb80000000000
#> 13 63bbc80000000000 63bbc80000000000
#> 14 63bbd80000000000 63bbd80000000000
#> 15 63bbe80000000000 63bbe80000000000
#> 16 63be380000000000 63be380000000000
#> 17 63be880000000000 63beb80000000000
#> 18 63bec80000000000 63bef80000000000
```
