# Get or set the number of threads used by a5R

Controls the number of threads used for parallel processing in
vectorised functions. One thread (the default) runs sequentially with no
overhead; more run in parallel via rayon. As with
[`options()`](https://rdrr.io/r/base/options.html) and
[`par()`](https://rdrr.io/r/graphics/par.html), `a5_threads()` reports
the current count and `a5_threads(n)` sets it.

## Usage

``` r
a5_threads(n = NULL)

# S3 method for class 'a5_threads'
with(data, expr, ...)
```

## Arguments

- n:

  `NULL` (the default) to report the current count, or an integer scalar
  of at least 1 to set it. The value returned by an earlier
  `a5_threads(n)` call also works.

- data:

  The value of `a5_threads(n)`.

- expr:

  Code to run with that thread count.

- ...:

  Unused.

## Value

`a5_threads()`: the current count, an integer scalar. `a5_threads(n)`:
the previous count, invisibly, as an `a5_threads` object.
[`with()`](https://rdrr.io/r/base/with.html): the value of `expr`.

## Details

`a5_threads(n)` returns the previous thread count, so a change can be
scoped to a block of code with
[`with()`](https://rdrr.io/r/base/with.html), as `mirai::daemons()` is:
`with(a5_threads(4), expr)` runs `expr` on four threads and then
restores the previous count, even if `expr` fails.

The count can also be set before the package loads, with the option
`a5R.threads` or the environment variable `A5R_NUM_THREADS`.

A forked worker, as created by
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html) or
`future::multicore`, inherits the count but not the threads, so a5R runs
on one thread there until the worker calls `a5_threads()` itself.
Separate-process workers, as from `mirai` or `future::multisession`,
start at one thread like any new session.

## Examples

``` r
a5_threads()
#> [1] 1

cells <- a5_lonlat_to_cell(runif(1000, -180, 180), runif(1000, -80, 80), 10)
b <- with(a5_threads(2), a5_cell_to_boundary(cells))
a5_threads()
#> [1] 1
```
