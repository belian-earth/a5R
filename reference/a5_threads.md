# Set the number of threads used by a5R

Controls the number of threads used for parallel processing in
vectorised functions. Set to 1 (the default) for sequential processing
with zero overhead, or higher for parallel execution via rayon.

## Usage

``` r
a5_set_threads(n = 1L)

a5_get_threads()
```

## Arguments

- n:

  Integer scalar. Number of threads. Must be \>= 1.

## Value

Invisibly returns the previous thread count.

Integer scalar.
