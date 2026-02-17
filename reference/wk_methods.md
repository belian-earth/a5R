# wk methods for a5_cell

Integration with the
[wk](https://paleolimbot.github.io/wk/reference/wk-package.html)
geometry framework. Allows `a5_cell` vectors to be handled as geometry
(via their boundary polygons) and to report their CRS.

## Usage

``` r
# S3 method for class 'a5_cell'
wk_handle(handleable, handler, ...)

# S3 method for class 'a5_cell'
wk_crs(x)
```

## Arguments

- handleable, x:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector.

- handler:

  A [wk
  handler](https://paleolimbot.github.io/wk/reference/wk_handle.html).

- ...:

  Passed to underlying methods.
