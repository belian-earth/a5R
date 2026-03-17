# Navigate to parent cell(s)

Returns the parent cell of each input cell. By default returns the
immediate parent (one resolution coarser). Optionally target a specific
coarser resolution.

## Usage

``` r
a5_cell_to_parent(cell, resolution = NULL)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target parent resolution, or `NULL` for the immediate
  parent.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector of parent cells.

## See also

[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md),
[`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
a5_cell_to_parent(cell)
#> <a5_cell[1]>
#> [1] 6344be0000000000
a5_cell_to_parent(cell, resolution = 5)
#> <a5_cell[1]>
#> [1] 6346000000000000
```
