# The i-th child of each cell

Returns one descendant of each cell at a finer resolution without
enumerating the others: the `i`-th element of what
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
would return. Useful for random draws from large cells, where building
the full child list to pick one element is wasteful.

## Usage

``` r
a5_cell_child(cell, child_resolution, i)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- child_resolution:

  Integer scalar target resolution, at or finer than every cell's own
  resolution.

- i:

  Integer vector of 1-based child positions, recycled against `cell`.
  Must lie within `1:a5_get_num_children(res, child_resolution)` for
  each cell's resolution `res`; out of range is an error.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector the same length as `cell`. `NA` where `cell` or `i` is `NA`.

## See also

[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md),
[`a5_get_num_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_child(cell, child_resolution = 7, i = 1:16)
#> <a5_cell[16]>
#>  [1] 6314200000000000 6314600000000000 6314a00000000000 6314e00000000000
#>  [5] 6315200000000000 6315600000000000 6315a00000000000 6315e00000000000
#>  [9] 6316200000000000 6316600000000000 6316a00000000000 6316e00000000000
#> [13] 6317200000000000 6317600000000000 6317a00000000000 6317e00000000000
identical(a5_cell_child(cell, 7, 1:16), a5_cell_to_children(cell, 7))
#> [1] TRUE
```
