# Average cell edge length at a given resolution

Returns the average length of a cell edge at the given resolution(s).
Individual edge lengths vary from this average by roughly +/-10%,
depending on the cell's shape and its position on the globe. Use this
for a quick estimate of cell size when choosing a resolution; use
[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
to measure a specific cell.

## Usage

``` r
a5_cell_edge_length_avg(resolution, units = "m")
```

## Arguments

- resolution:

  Integer vector of resolutions (0–30).

- units:

  Character scalar specifying the output length unit (default `"m"`).
  Any unit convertible from `m` via
  [`units::set_units()`](https://r-quantities.github.io/units/reference/units.html)
  is accepted (e.g. `"km"`, `"mi"`). If NULL, the length is returned as
  a numeric vector in metres.

## Value

A
[units::units](https://r-quantities.github.io/units/reference/units.html)
vector of average edge lengths, or a numeric vector if `units = NULL`.

## See also

[`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_area.md)

## Examples

``` r
a5_cell_edge_length_avg(0:5)
#> Units: [m]
#> [1] 4649142.3 4320430.2 1190173.8  597565.2  299147.1  149610.0
a5_cell_edge_length_avg(10, units = "km")
#> 4.675881 [km]
```
