# Convert A5 cell indices to coordinates

Returns the centre-point longitude and latitude of each cell.

## Usage

``` r
a5_cell_to_lonlat(cell, as_dataframe = FALSE)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector (or character coercible to one).

- as_dataframe:

  Logical scalar controlling the return container. When `FALSE`
  (default), centroids are returned as a
  [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
  vector with WGS 84 CRS, the geographic-typed form that plugs into
  wk/sf pipelines. When `TRUE`, centroids are returned as a base
  `data.frame` with columns `lon` and `lat`.

## Value

A [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
vector (if `as_dataframe = FALSE`) or a `data.frame` with columns `lon`
and `lat` (if `as_dataframe = TRUE`).

## See also

[`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_lonlat_to_cell.md)
for the inverse operation,
[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
for full cell polygons.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_to_lonlat(cell)
#> <wk_xy[1] with CRS=OGC:CRS84>
#> [1] (-3.280745 56.43135)

# Data frame output
cell2 <- a5_lonlat_to_cell(114.8, 4.1, resolution = 5)
a5_cell_to_lonlat(cell2, as_dataframe = TRUE)
#>        lon      lat
#> 1 114.9474 4.191425
```
