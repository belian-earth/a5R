# Get child cells

Returns the child cells of a single cell. By default returns the 4
immediate children (one resolution finer). Optionally target a specific
finer resolution.

## Usage

``` r
a5_cell_to_children(cell, resolution = NULL)
```

## Arguments

- cell:

  A single
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  value.

- resolution:

  Integer scalar target child resolution, or `NULL` for immediate
  children.

## Value

An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector of child cells.

## See also

[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_parent.md),
[`a5_get_resolution()`](https://belian-earth.github.io/a5R/reference/a5_get_resolution.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_to_children(cell)
#> <a5_cell[4]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000
```
