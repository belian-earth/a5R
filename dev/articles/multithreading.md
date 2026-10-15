# Multi-threading

``` r

library(a5R)
#> a5R 0.9.9.9002 • a5 crate 1.0.0-beta.3 • A5 index 1.0 • 1 thread
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
environment variable, useful for scripts and batch jobs:

``` r

# In .Rprofile or at the top of a script
options(a5R.threads = 4)

# Or as an environment variable
# Sys.setenv(A5R_NUM_THREADS = 4) 
```

To use more threads for one block of code only, wrap it in
[`with()`](https://rdrr.io/r/base/with.html), as with
`mirai::daemons()`. The previous count is restored afterwards, even if
the code fails:

``` r

cells <- a5_lonlat_to_cell(runif(1e4, -180, 180), runif(1e4, -80, 80), 10)
boundaries <- with(a5_set_threads(4), {
  a5_cell_to_boundary(cells)
})
a5_get_threads()
#> [1] 1
```

[`a5_set_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
also returns the previous count, so `old <- a5_set_threads(4)` and later
`a5_set_threads(old)` work too.

## What gets parallelised

Threading applies to **vectorised** functions that process each element
independently:

| Function | Per-element cost | Benefit |
|----|----|----|
| [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md) | Heavy (boundary + WKT/WKB) | High |
| [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md) | Heavy (per-part fill, hole subtraction) | High |
| [`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_linestring_to_cells.md) | Heavy (per-feature tracing) | High |
| [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md) | Heavy (per-cell search) | High |
| [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md) | Heavy (per-cell traversal) | High |
| [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md) | Moderate (projection) | High |
| [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md) | Moderate (2x projection + distance) | Medium |
| [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md) | Moderate (reverse projection) | Medium |
| [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md) | Light (bit ops per child) | Low |
| [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md) | Light (bit ops + hex) | Low |
| [`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md) | Light (bit ops) | Low |
| [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md) | Light (per-covering expansion) | Low |
| [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md) | Light (bit checks) | Low |

For the one-to-many functions
([`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md),
[`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md),
[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md),
[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md))
the per-element work is parallelised; assembling the result, especially
the `simplify = FALSE` list, is sequential, so the list form gains less
than the flat form.

Scalar and bulk operations
([`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md),
[`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md),
[`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md),
[`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md),
etc.) are unaffected: they are already fast or delegate to algorithms
that don’t parallelise element-wise.

## When is it worthwhile?

Threading has a small fixed overhead (thread synchronisation, memory
allocation for intermediate results). For small vectors this can
outweigh the benefit. As a rule of thumb:

- **\< 1,000 elements**: stick with 1 thread
- **1,000–10,000**: 2-4 threads helps for heavy ops (boundary, indexing)
- **\> 10,000**: use as many threads as you have cores

Here is a quick comparison on about 700,000 cells:

``` r

cells <- a5_uncompact(a5_polygon_to_cells(wk::rct(-10, 50, 10, 60), resolution = 12))
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
while `elapsed` (wall-clock) time decreases: that is the parallelism at
work.

## Thread safety

a5R uses a dedicated rayon thread pool, separate from R’s own
parallelism. It is safe to use alongside `future`, `mirai`, etc. but
think carefully about this nested parallelism as it can, if overloaded,
degrade performance.

The thread pool is rebuilt each time you call
[`a5_set_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md),
so changing the count mid-session is fine (and cheap) but not free:
ideally, do it once at the start of your workflow rather than toggling
per-call.
