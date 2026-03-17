# Multi-threading

``` r
library(a5R)
```

a5R can parallelise vectorised operations using multiple threads via
[rayon](https://docs.rs/rayon). By default a5R uses a single thread, so
there is zero overhead. You opt in to parallelism when you need it.

## Setting the thread count

``` r
# Check the current setting (default: 1)
a5_get_threads()
#> [1] 1

# Use 4 threads
a5_set_threads(4)
a5_get_threads()
#> [1] 4
```

You can also set threads at package load time via an R option or
environment variable - useful for scripts and batch jobs:

``` r
# In .Rprofile or at the top of a script
options(a5R.threads = 4)

# Or as an environment variable
# Sys.setenv(A5R_NUM_THREADS = 4) 
```

[`a5_set_threads()`](https://belian-earth.github.io/a5R/reference/a5_threads.md)
invisibly returns the previous value, making temporary changes easy:

``` r
old <- a5_set_threads(4)
# ... parallel work ...
a5_set_threads(old)
```

## What gets parallelised

Threading applies to **vectorised** functions that process each element
independently:

| Function                                                                                       | Per-element cost                    | Benefit |
|------------------------------------------------------------------------------------------------|-------------------------------------|---------|
| [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_boundary.md) | Heavy (boundary + WKT/WKB)          | High    |
| [`a5_grid()`](https://belian-earth.github.io/a5R/reference/a5_grid.md)                         | Heavy (boundary filtering)          | High    |
| [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_lonlat_to_cell.md)     | Moderate (projection)               | High    |
| [`a5_cell_distance()`](https://belian-earth.github.io/a5R/reference/a5_cell_distance.md)       | Moderate (2x projection + distance) | Medium  |
| [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_lonlat.md)     | Moderate (reverse projection)       | Medium  |
| [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_parent.md)     | Light (bit ops + hex)               | Low     |
| [`a5_get_resolution()`](https://belian-earth.github.io/a5R/reference/a5_get_resolution.md)     | Light (bit ops)                     | Low     |
| [`a5_is_cell()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)                      | Light (hex parse)                   | Low     |

Scalar and bulk operations
([`a5_cell_to_children()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_children.md),
[`a5_compact()`](https://belian-earth.github.io/a5R/reference/a5_compact.md),
[`a5_cell_area()`](https://belian-earth.github.io/a5R/reference/a5_cell_area.md),
etc.) are unaffected — they are already fast or delegate to algorithms
that don’t parallelise element-wise.

## When is it worthwhile?

Threading has a small fixed overhead (thread synchronisation, memory
allocation for intermediate results). For small vectors this can
outweigh the benefit. As a rule of thumb:

- **\< 1,000 elements**: stick with 1 thread
- **1,000–10,000**: 2-4 threads helps for heavy ops (boundary, indexing)
- **\> 10,000**: use as many threads as you have cores

Here’s a quick comparison on 100k cells:

``` r
cells <- a5_grid(c(-10, 50, 10, 60), resolution = 12)
length(cells)
#> [1] 704259

a5_set_threads(1)
system.time(a5_cell_to_boundary(cells, format = "wkt"))
#>   user  system elapsed
#>  3.124   0.000   3.122 

a5_set_threads(8)
system.time(a5_cell_to_boundary(cells, format = "wkt"))
#>   user  system elapsed
#> 6.195   1.289   1.667 
```

Note that `user` time increases (total CPU work across all threads)
while `elapsed` (wall-clock) time decreases — that’s the parallelism at
work.

## Thread safety

a5R uses a dedicated rayon thread pool, separate from R’s own
parallelism. It is safe to use alongside `future`, `mirai`, etc. but
think carefully about this nested parallelism as it can, if overloaded,
degrade performance.

The thread pool is rebuilt each time you call
[`a5_set_threads()`](https://belian-earth.github.io/a5R/reference/a5_threads.md),
so changing the count mid-session is fine (and cheap) but not free -
ideally, just do it once at the start of your workflow rather than
toggling per-call.
