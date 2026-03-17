# Distance between cell centroids

Computes the distance between the centroids of pairs of A5 cells using
the specified method.

## Usage

``` r
a5_cell_distance(
  from,
  to,
  units = "m",
  method = c("haversine", "geodesic", "rhumb")
)
```

## Arguments

- from, to:

  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vectors (recycled to common length).

- units:

  Character scalar specifying the distance unit (default `"m"`). Any
  unit convertible from metres via
  [`units::set_units()`](https://r-quantities.github.io/units/reference/units.html)
  is accepted (e.g. `"km"`, `"mi"`). If NULL, the distance is returned
  as a numeric vector in metres.

- method:

  Distance calculation method. One of `"haversine"` (great-circle,
  default), `"geodesic"` (WGS84 ellipsoid via Karney 2013), or `"rhumb"`
  (loxodrome / constant-bearing).

## Value

A
[units::units](https://r-quantities.github.io/units/reference/units.html)
vector of distances.

## See also

[`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_lonlat.md)
for cell centroids,
[`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_area.md)
for cell areas.

## Examples

``` r
a <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 24)
b <- a5_lonlat_to_cell(-3.10, 55.90, resolution = 24)
a5_cell_distance(a, b)
#> 7896.049 [m]
a5_cell_distance(a, b, units = "km")
#> 7.896049 [km]
a5_cell_distance(a, b, method = "geodesic")
#> 7914.811 [m]
```
