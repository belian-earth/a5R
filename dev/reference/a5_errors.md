# Error classes

Errors raised by a5R have class `a5R_error`, so code can catch them
apart from other errors, and most also have a class naming what went
wrong:

## Details

- `a5R_error_resolution`: a resolution that is missing, out of range, or
  on the wrong side of a cell's own resolution.

- `a5R_error_geometry`: coordinates or geometries that cannot be
  indexed, such as latitudes beyond 90 degrees, projected coordinates,
  or malformed rings.

- `a5R_error_cell`: input that cannot be read as cells or coverings,
  such as a string that is not a hex id.

- `a5R_error_arrow`: Arrow input of the wrong type.

- `a5R_error_size`: a result too large to build.

- `a5R_error_argument`: any other invalid argument.

Errors from the a5 Rust library carry only `a5R_error` unless a5R can
tell what they concern.

## Examples

``` r
res <- tryCatch(
  a5_lonlat_to_cell(0, 91, resolution = 5),
  a5R_error_geometry = function(e) "bad coordinates"
)
res
#> [1] "bad coordinates"
```
