# Get the resolution of A5 cell indices

Extracts the resolution level (0–30) encoded in each cell index.

## Usage

``` r
a5_get_resolution(cell)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

## Value

An integer vector of resolutions.

## See also

[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_parent.md),
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
a5_get_resolution(cell)
#> [1] 10
```
