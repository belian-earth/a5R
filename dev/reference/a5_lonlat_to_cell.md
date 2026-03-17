# Convert coordinates to A5 cell indices

Maps longitude/latitude coordinates to A5 cell indices at the specified
resolution.

## Usage

``` r
a5_lonlat_to_cell(lon, lat, resolution)
```

## Arguments

- lon:

  Numeric vector of longitudes in degrees.

- lat:

  Numeric vector of latitudes in degrees.

- resolution:

  Integer scalar or vector of resolutions (0–30).

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector of cell indices.

## See also

[`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_lonlat.md)
for the inverse operation.

## Examples

``` r
a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
#> <a5_cell[1]>
#> [1] 633e000000000000
```
