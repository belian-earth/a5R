# Deprecated thread functions

`a5_set_threads()` and `a5_get_threads()` are replaced by
[`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md),
which both sets and reports the count. They still work but warn.

## Usage

``` r
a5_set_threads(n = 1L)

a5_get_threads()
```

## Arguments

- n:

  Integer scalar. Number of threads.

## Value

As
[`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md).
