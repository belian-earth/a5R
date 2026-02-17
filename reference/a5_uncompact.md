# Uncompact a set of A5 cells to a target resolution

Expands each cell to its descendants at the target resolution.

## Usage

``` r
a5_uncompact(cells, resolution)
```

## Arguments

- cells:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target resolution (0–30).

## Value

An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector of uncompacted cells.

## See also

[`a5_compact()`](https://belian-earth.github.io/a5R/reference/a5_compact.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_uncompact(cell, resolution = 7)
#> <a5_cell[16]>
#>  [1] 633c200000000000 633c600000000000 633ca00000000000 633ce00000000000
#>  [5] 633d200000000000 633d600000000000 633da00000000000 633de00000000000
#>  [9] 633e200000000000 633e600000000000 633ea00000000000 633ee00000000000
#> [13] 633f200000000000 633f600000000000 633fa00000000000 633fe00000000000
```
