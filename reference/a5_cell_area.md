# Cell area at a given resolution

Returns the area of a single cell in square metres at the given
resolution(s). Because A5 is an equal-area DGGS, all cells at the same
resolution have identical area.

## Usage

``` r
a5_cell_area(resolution, units = "m^2")
```

## Arguments

- resolution:

  Integer vector of resolutions (0–30).

- units:

  Character scalar specifying the output area unit (default `"m^2"`).
  Any unit convertible from `m^2` via
  [`units::set_units()`](https://r-quantities.github.io/units/reference/units.html)
  is accepted (e.g. `"km^2"`, `"ha"`, `"acre"`).

## Value

A
[units::units](https://r-quantities.github.io/units/reference/units.html)
vector of areas.

## Examples

``` r
a5_cell_area(0:5)
#> Units: [m^2]
#> [1] 4.250547e+13 8.501094e+12 2.125273e+12 5.313184e+11 1.328296e+11
#> [6] 3.320740e+10
a5_cell_area(5, units = "km^2")
#> 33207.4 [km^2]
```
