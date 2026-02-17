# Convert A5 cell indices to coordinates

Returns the centre-point longitude and latitude of each cell.

## Usage

``` r
a5_cell_to_lonlat(cell, normalise = TRUE)
```

## Arguments

- cell:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector (or character coercible to one).

- normalise:

  Logical scalar. If `TRUE` (default), longitudes are wrapped to the
  \\\[-180, 180\]\\ range and the result is returned as a
  [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
  vector. If `FALSE`, the raw unwrapped coordinates from the Rust API
  are returned as a two-column data frame (`lon`, `lat`).

## Value

If `normalise = TRUE`, a
[`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html) vector
of (longitude, latitude) points. If `normalise = FALSE`, a data frame
with columns `lon` and `lat` containing the unwrapped coordinates.

## Details

The underlying Rust API returns longitudes in a continuous unwrapped
range that can exceed \\\[-180, 180\]\\ for cells near the antimeridian
(e.g. \\-245\\ instead of \\115\\). By default these are normalised to
standard bounds. Set `normalise = FALSE` to retrieve the raw values,
which can be useful for avoiding discontinuities in calculations that
span the antimeridian.

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

# Raw unwrapped coordinates
cell2 <- a5_lonlat_to_cell(114.8, 4.1, resolution = 5)
a5_cell_to_lonlat(cell2, normalise = FALSE)
#>         lon      lat
#> 1 -245.0526 4.191425
```
