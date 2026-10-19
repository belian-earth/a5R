# Multi-threading

``` r

library(a5R)
#> a5R 1.0.0.9000 • a5 crate 1.0.0 • A5 index 1.0 • 1 thread
```

a5R can parallelise vectorised operations across threads with
[rayon](https://docs.rs/rayon), a Rust library for data parallelism. By
default a5R uses a single thread, so there is no overhead; you opt in to
parallelism when you need it. Work is split across elements, so a single
polygon part, covering or centre cell gains nothing.

## Setting the thread count

[`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
reports the thread count and `a5_threads(n)` sets it, as
[`options()`](https://rdrr.io/r/base/options.html) and
[`par()`](https://rdrr.io/r/graphics/par.html) do:

``` r

a5_threads() # the default: 1
#> [1] 1

a5_threads(2)
a5_threads()
#> [1] 2
```

[`a5_info()`](https://belian-earth.github.io/a5R/dev/reference/a5_info.md)
also reports the count. To set it for a whole script or batch job, set
an R option or environment variable before
[`library(a5R)`](https://github.com/belian-earth/a5R); both are read
when the package loads:

``` r

# In .Rprofile or at the top of a script
options(a5R.threads = 4)
```

``` sh
A5R_NUM_THREADS=4 Rscript script.R
```

To use more threads for one block of code only, wrap it in
[`with()`](https://rdrr.io/r/base/with.html), as with
`mirai::daemons()`. The previous count is restored afterwards, even if
the code fails:

``` r

set.seed(1)
cells <- a5_lonlat_to_cell(runif(1e4, -180, 180), runif(1e4, -80, 80), 10)
boundaries <- with(a5_threads(2), {
  a5_cell_to_boundary(cells)
})
a5_threads()
#> [1] 1
```

Setting a count returns the previous one, so `old <- a5_threads(4)` and
later `a5_threads(old)` work too.

## What gets parallelised

Threading applies to **vectorised** functions that process each element
independently:

| Function | Per-element cost | Benefit |
|----|----|----|
| [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md), [`a5_cell_to_boundary_xy()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary_xy.md) | Heavy (boundary + WKB/WKT) | High |
| [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md) | Heavy (per-part fill, hole subtraction) | High |
| [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md) | Heavy (per-feature tracing) | High |
| [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md), [`a5_grid_disk_vertex()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md), [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md) | Heavy (per-cell traversal) | High |
| [`a5_cell_to_subcells()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md) | Heavy (per-cell search) | High |
| [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md), [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md) | Moderate (projection) | High |
| [`a5_cell_to_supercell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md) | Moderate (projection) | High |
| [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md) | Moderate (2 projections + distance) | Medium |
| `a5_union(x, y)`, [`a5_intersect()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md), [`a5_difference()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md), [`a5_contains()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md), [`a5_overlaps()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md) | Varies with covering size | Medium |
| [`a5_covering_to_supercells()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_to_supercells.md) | Search within each covering | Medium |
| [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md), [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md) | Light (per-element expansion) | Low |
| [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md), [`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md), [`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md) | Light (bit operations) | Low |

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
[`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md))
are unaffected: they are already fast or do not split by element.

## When is it worthwhile?

Each parallel call pays a small fixed cost to hand work to the threads.
For small vectors this can outweigh the benefit. As a rule of thumb:

- **\< 1,000 elements**: stick with 1 thread
- **1,000–10,000**: 2–4 threads help for heavy operations (boundaries,
  indexing)
- **\> 10,000**: use as many threads as you have cores

Here is a comparison on about 695,000 cells:

``` r

cells <- a5_uncompact(a5_polygon_to_cells(wk::rct(-10, 50, 10, 60), resolution = 12))
length(cells)
#> [1] 694889

a5_threads(1)
system.time(a5_cell_to_boundary(cells))
#>    user  system elapsed
#>   0.952   0.005   0.956

a5_threads(8)
system.time(a5_cell_to_boundary(cells))
#>    user  system elapsed
#>   1.206   0.009   0.248
```

`user` time (total CPU work across all threads) rises while `elapsed`
(wall-clock) time falls: that is the parallelism at work.

## Other parallel code

a5R uses its own rayon thread pool, separate from R’s parallelism.
Combining the two multiplies the thread count, so keep the product
within your cores:

- Separate-process workers (`mirai`, `future::multisession`, PSOCK
  clusters) start at one a5R thread, like any new session. Raise it
  inside a worker only if the workers leave cores idle.
- Forked workers
  ([`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html),
  `future::multicore`) inherit the count but not the threads, so a5R
  runs on one thread in each of them unless the worker calls
  `a5_threads(n)` itself.

Each `a5_threads(n)` call rebuilds the thread pool, which takes well
under a millisecond, so scoping a count with
[`with()`](https://rdrr.io/r/base/with.html) around each heavy call
costs nothing measurable.
