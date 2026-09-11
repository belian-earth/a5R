# The i-th child of each cell

Returns one descendant of each cell at a finer resolution without
enumerating the others: the `i`-th element of what
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md)
would return. Useful for random draws from large cells, where building
the full child list to pick one element is wasteful.

## Usage

``` r
a5_cell_child(cell, resolution, i)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution, at or finer than every cell's own
  resolution.

- i:

  Integer vector of 1-based child positions, recycled against `cell`.
  Must lie within `1:a5_get_num_children(res, resolution)` for each
  cell's resolution `res`; out of range is an error.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector the same length as `cell`. `NA` where `cell` or `i` is `NA`.

## See also

[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md),
[`a5_get_num_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_num_children.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_child(cell, resolution = 7, i = 1:16)
#> <a5_cell[16]>
#>  [1] 633c200000000000 633c600000000000 633ca00000000000 633ce00000000000
#>  [5] 633d200000000000 633d600000000000 633da00000000000 633de00000000000
#>  [9] 633e200000000000 633e600000000000 633ea00000000000 633ee00000000000
#> [13] 633f200000000000 633f600000000000 633fa00000000000 633fe00000000000
identical(a5_cell_child(cell, 7, 1:16), a5_cell_to_children(cell, 7))
#> [1] TRUE
```
