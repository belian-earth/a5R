# Convert A5 cell indices to coordinates

Returns the centre-point longitude and latitude of each cell.

## Usage

``` r
a5_cell_to_lonlat(cell)
```

## Arguments

- cell:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector (or character coercible to one).

## Value

A [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
vector of (longitude, latitude) points.

## See also

[`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_lonlat_to_cell.md)
for the inverse operation,
[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_boundary.md)
for full cell polygons.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_to_lonlat(cell)
#> <wk_xy[1] with CRS=OGC:CRS84>
#> [1] (-3.280745 56.43135)
```
