# Compact a set of A5 cells

Merges complete sibling groups into their common parent, reducing the
number of cells while preserving coverage.

## Usage

``` r
a5_compact(cells)
```

## Arguments

- cells:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector of compacted cells.

## See also

[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_uncompact.md)

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
children <- a5_cell_to_children(cell)
a5_compact(children) # back to the parent
#> <a5_cell[1]>
#> [1] 633e000000000000
```
