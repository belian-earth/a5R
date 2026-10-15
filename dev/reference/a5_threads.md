# Set the number of threads used by a5R

Controls the number of threads used for parallel processing in
vectorised functions. Set to 1 (the default) for sequential processing
with zero overhead, or higher for parallel execution via rayon.

## Usage

``` r
a5_set_threads(n = 1L)

# S3 method for class 'a5_threads'
with(data, expr, ...)

a5_get_threads()
```

## Arguments

- n:

  Integer scalar. Number of threads. Must be \>= 1. The value returned
  by an earlier `a5_set_threads()` call also works.

- data:

  The value of `a5_set_threads()`.

- expr:

  Code to run with that thread count.

- ...:

  Unused.

## Value

`a5_set_threads()`: the previous thread count, invisibly, as an
`a5_threads` object. [`with()`](https://rdrr.io/r/base/with.html): the
value of `expr`. `a5_get_threads()`: the current count, an integer
scalar.

## Details

`a5_set_threads()` returns the previous thread count, so a change can be
scoped to a block of code with
[`with()`](https://rdrr.io/r/base/with.html), as `mirai::daemons()` is:
`with(a5_set_threads(4), expr)` runs `expr` on four threads and then
restores the previous count, even if `expr` fails.

## Examples

``` r
cells <- a5_lonlat_to_cell(runif(1000, -180, 180), runif(1000, -80, 80), 10)
b <- with(a5_set_threads(2), a5_cell_to_boundary(cells))
a5_get_threads()
#> [1] 1
```
