# Get child cells

Returns the child cells of each input cell. By default returns the 4
immediate children (one resolution finer). Optionally target a specific
finer resolution.

## Usage

``` r
a5_cell_to_children(cell, resolution = NULL, simplify = TRUE)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- resolution:

  Integer scalar target child resolution, or `NULL` for immediate
  children.

- simplify:

  Logical scalar. If `TRUE` (default), return one flat
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector with the children of every input concatenated in input order;
  which child came from which parent is not recorded. If `FALSE`, return
  an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md):
  a [`vctrs::list_of()`](https://vctrs.r-lib.org/reference/list_of.html)
  of
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vectors with one element per input, suitable for a list column.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector, or an
[a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
when `simplify = FALSE`. An `NA` input contributes no cells (an empty
element in the list form).

## See also

[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_parent.md),
[`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md),
[`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
for one child at a time,
[`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
for the id range of all descendants.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_to_children(cell)
#> <a5_cell[4]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000

cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
a5_cell_to_children(cells, resolution = 7)                  # 32 cells
#> <a5_cell[32]>
#>  [1] 633c200000000000 633c600000000000 633ca00000000000 633ce00000000000
#>  [5] 633d200000000000 633d600000000000 633da00000000000 633de00000000000
#>  [9] 633e200000000000 633e600000000000 633ea00000000000 633ee00000000000
#> [13] 633f200000000000 633f600000000000 633fa00000000000 633fe00000000000
#> [17] 4f04200000000000 4f04600000000000 4f04a00000000000 4f04e00000000000
#> [21] 4f05200000000000 4f05600000000000 4f05a00000000000 4f05e00000000000
#> [25] 4f06200000000000 4f06600000000000 4f06a00000000000 4f06e00000000000
#> [29] 4f07200000000000 4f07600000000000 4f07a00000000000 4f07e00000000000
a5_cell_to_children(cells, resolution = 7, simplify = FALSE) # list of 2
#> <a5_cell_list[2]>
#> [[1]]
#> <a5_cell[16]>
#>  [1] 633c200000000000 633c600000000000 633ca00000000000 633ce00000000000
#>  [5] 633d200000000000 633d600000000000 633da00000000000 633de00000000000
#>  [9] 633e200000000000 633e600000000000 633ea00000000000 633ee00000000000
#> [13] 633f200000000000 633f600000000000 633fa00000000000 633fe00000000000
#> 
#> [[2]]
#> <a5_cell[16]>
#>  [1] 4f04200000000000 4f04600000000000 4f04a00000000000 4f04e00000000000
#>  [5] 4f05200000000000 4f05600000000000 4f05a00000000000 4f05e00000000000
#>  [9] 4f06200000000000 4f06600000000000 4f06a00000000000 4f06e00000000000
#> [13] 4f07200000000000 4f07600000000000 4f07a00000000000 4f07e00000000000
#> 
```
