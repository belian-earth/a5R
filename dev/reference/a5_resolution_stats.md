# Cell size and counts by resolution

Properties of the grid at a resolution, independent of any particular
cell:

## Usage

``` r
a5_cell_area(resolution, units = "m^2")

a5_cell_edge_length_avg(resolution, units = "m")

a5_get_num_cells(resolution)

a5_get_num_children(parent_resolution, child_resolution)
```

## Arguments

- resolution:

  Integer vector of resolutions (0–30). A scalar for
  `a5_get_num_cells()`.

- units:

  Character scalar giving the output unit: an area unit for
  `a5_cell_area()` (default `"m^2"`), a length unit for
  `a5_cell_edge_length_avg()` (default `"m"`). Any unit
  [`units::set_units()`](https://rdrr.io/pkg/units/man/units.html) can
  convert to is accepted (e.g. `"km^2"`, `"ha"`, `"km"`, `"mi"`). If
  `NULL`, a plain numeric vector in square metres or metres is returned.

- parent_resolution, child_resolution:

  Integer scalars (0–30), with `child_resolution` at or finer than
  `parent_resolution`.

## Value

- `a5_cell_area()`, `a5_cell_edge_length_avg()`: a
  [units::units](https://rdrr.io/pkg/units/man/units.html) vector the
  length of `resolution`, or numeric when `units = NULL`.

- `a5_get_num_cells()`, `a5_get_num_children()`: a numeric scalar.
  Counts are doubles because they can exceed R's integer range.

## Details

- `a5_cell_area()`: the area of one cell. A5 is an equal-area grid, so
  every cell at a resolution has the same area.

- `a5_cell_edge_length_avg()`: the average cell edge length. Individual
  edges vary from this by roughly +/-10%, depending on the cell's shape
  and position; use
  [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  to measure a specific cell.

- `a5_get_num_cells()`: the number of cells covering the globe.

- `a5_get_num_children()`: the number of descendants each cell has at a
  finer resolution, as returned by
  [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md).

Use the first two to choose a resolution for a target cell size.

## Examples

``` r
a5_cell_area(0:5)
#> Units: [m^2]
#> [1] 4.250547e+13 8.501094e+12 2.125273e+12 5.313184e+11 1.328296e+11
#> [6] 3.320740e+10
a5_cell_area(5, units = "km^2")
#> 33207.4 [km^2]
a5_cell_edge_length_avg(10, units = "km")
#> 4.675881 [km]

a5_get_num_cells(10)
#> [1] 15728640
a5_get_num_children(5, 8) # 4^3 = 64
#> [1] 64

# cells at a resolution times their area covers the globe
a5_get_num_cells(10) * a5_cell_area(10, units = "km^2")
#> 510065625 [km^2]
```
