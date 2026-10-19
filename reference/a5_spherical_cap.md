# Cells within a great-circle radius

Returns, for each centre cell, the cells whose centres fall within a
great-circle distance of its centre, as an
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md).

## Usage

``` r
a5_spherical_cap(cell, radius, units = "m")
```

## Arguments

- cell:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector of centre cells.

- radius:

  Non-negative numeric scalar, great-circle radius in `units`, or a
  [units](https://r-quantities.github.io/units/reference/units.html)
  object of length. It is measured on the sphere A5 uses internally, so
  membership can differ by a fraction of a percent of `radius` from
  distances given by
  [`a5_cell_distance()`](https://belian-earth.github.io/a5R/reference/a5_cell_distance.md).

- units:

  Character scalar, the length unit of a plain numeric `radius`: `"m"`
  (the default) or any unit convertible from metres, such as `"km"`.

## Value

An
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md)
vector the same length as `cell`, at the resolution of each centre cell.
`NA` where `cell` is `NA`. Use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md)
for the cells.

## See also

[`a5_grid_disk()`](https://belian-earth.github.io/a5R/reference/a5_grid_disk.md)
for hop-based selection.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 8)
cap <- a5_spherical_cap(cell, radius = 1000)
cap
#> <a5_covering[1]>
#> [1] res 8: 1 cell (1 stored)
a5_uncompact(cap)
#> <a5_cell[1]>
#> [1] 63bb980000000000
```
