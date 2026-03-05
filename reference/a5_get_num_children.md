# Number of children between two resolutions

Returns the number of child cells each parent cell contains when
expanding from one resolution to another.

## Usage

``` r
a5_get_num_children(parent_resolution, child_resolution)
```

## Arguments

- parent_resolution:

  Integer scalar (0–30).

- child_resolution:

  Integer scalar (0–30), must be \>= `parent_resolution`.

## Value

A numeric scalar. Returned as double because the count can exceed R's
integer range at large resolution deltas.

## See also

[`a5_get_num_cells()`](https://belian-earth.github.io/a5R/reference/a5_get_num_cells.md),
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_children.md),
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_uncompact.md)

## Examples

``` r
a5_get_num_children(5, 8)   # 4^3 = 64
#> [1] 64
a5_get_num_children(0, 5)
#> [1] 1280
```
