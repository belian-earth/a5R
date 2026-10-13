# Measure coverings

`a5_count()` returns the number of cells each covering stands for at its
resolution: the length of its
[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
result, without building it. This differs from the number of cells
stored. `a5_area()` returns the area of each covering. A5 cells are
equal-area, so this is exact up to rounding: the count times
[`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
at the covering's resolution.

## Usage

``` r
a5_count(x)

a5_area(x, units = "m^2")
```

## Arguments

- x:

  An
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector, or an object
  [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  accepts.

- units:

  Character scalar area unit for `a5_area()` (default `"m^2"`). Any unit
  [`units::set_units()`](https://r-quantities.github.io/units/reference/units.html)
  can convert to is accepted (e.g. `"km^2"`, `"ha"`). If `NULL`, a plain
  numeric vector in square metres.

## Value

`a5_count()`: a numeric vector the length of `x`. `a5_area()`: a
[units::units](https://r-quantities.github.io/units/reference/units.html)
vector the length of `x`, or numeric when `units = NULL`. `NA` for a
missing covering.

## Details

Counts are doubles, exact up to 2^53 (about 9e15 cells); coverings at
the finest resolutions can stand for more, and those counts are rounded.

## See also

[`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
for the area of a single cell.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 12)
cap <- a5_spherical_cap(cell, radius = 10000)
cap
#> <a5_covering[1]>
#> [1] res 12: 155 cells (53 stored)
a5_count(cap)
#> [1] 155
a5_area(cap, units = "km^2")
#> 314.1569 [km^2]
```
