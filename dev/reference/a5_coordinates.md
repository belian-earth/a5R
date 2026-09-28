# Convert between coordinates and cells

`a5_lonlat_to_cell()` maps longitude/latitude coordinates to the cell
containing each point at a resolution. `a5_cell_to_lonlat()` returns the
centre point of each cell. Indexing a cell's centre at the cell's own
resolution returns the cell.

## Usage

``` r
a5_lonlat_to_cell(lon, lat, resolution)

a5_cell_to_lonlat(cell, as_dataframe = FALSE)
```

## Arguments

- lon:

  Numeric vector of longitudes in degrees.

- lat:

  Numeric vector of latitudes in degrees.

- resolution:

  Integer scalar or vector of resolutions (0–30), recycled against `lon`
  and `lat`.

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector (or character coercible to one).

- as_dataframe:

  Logical scalar controlling the return container. When `FALSE`
  (default), centres are returned as a
  [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
  vector with WGS 84 CRS, the geographic-typed form that plugs into
  wk/sf pipelines. When `TRUE`, centres are returned as a base
  `data.frame` with columns `lon` and `lat`.

## Value

- `a5_lonlat_to_cell()`: an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

- `a5_cell_to_lonlat()`: a
  [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
  vector, or a `data.frame` with columns `lon` and `lat` when
  `as_dataframe = TRUE`.

## See also

[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
for full cell polygons,
[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
for areas.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
a5_cell_to_lonlat(cell)
#> <wk_xy[1] with CRS=OGC:CRS84>
#> [1] (-3.280745 56.43135)
a5_cell_to_lonlat(cell, as_dataframe = TRUE)
#>         lon      lat
#> 1 -3.280745 56.43135

# a cell's centre indexes back to the cell
ll <- a5_cell_to_lonlat(cell, as_dataframe = TRUE)
a5_lonlat_to_cell(ll$lon, ll$lat, resolution = 5) == cell
#> [1] TRUE
```
