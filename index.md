# a5R

a5R provides R bindings for the [A5](https://a5geo.org/) pentagonal
geospatial index, powered by the [a5 Rust
crate](https://crates.io/crates/A5) via
[extendr](https://extendr.github.io/extendr/extendr_api/).

A5 partitions the Earth’s surface into pentagonal cells across 31
resolution levels. Cells are equal-area, encoded as 64-bit integers, and
achieve millimetre-level precision at the finest resolution.

## Installation

``` r
# install.packages("pak")
pak::pak("belian-earth/a5R")
```

You will need a working [Rust toolchain](https://rustup.rs/) (`cargo`
and `rustc`).

## Quick example

``` r
library(a5R)

# Index a point to a cell
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
cell
#> <a5_cell[1]>
#> [1] 6344be8000000000

# Get the boundary polygon
a5_cell_to_boundary(cell)
#> <wk_wkb[1] with CRS=OGC:CRS84>
#> [1] <POLYGON ((-3.175718 55.93546, -3.145905 55.97569, -3.151641 56.01921, -3.219413 56.00818, -3.226037 55.96443, -3.175718 55.93546...>

# Navigate the hierarchy
a5_cell_to_parent(cell)
#> <a5_cell[1]>
#> [1] 6344be0000000000
a5_cell_to_children(cell)
#> <a5_cell[4]>
#> [1] 6344be2000000000 6344be6000000000 6344bea000000000 6344bee000000000
```

``` r
# Generate a grid covering an area
cells <- a5_grid(c(114.8, 4.1, 119.8, 8.1), resolution = 8)
plot(a5_cell_to_boundary(cells), col = "#206ead20", border = "#206ead", asp = 1)
```

![A5 grid cells covering part of Southeast Asia at resolution
8](reference/figures/README-grid-plot-1.png)

See
[`vignette("a5R")`](https://belian-earth.github.io/a5R/articles/a5R.md)
for a full walkthrough of indexing, boundaries, hierarchy, traversal,
and grid generation.

## Features

- **Vectorised Rust core** — all operations implemented in Rust and
  called from R via extendr.
  [Benchmarks](https://github.com/belian-earth/a5R/blob/main/benchmarks/RESULTS.md)
  confirm identical results to the Python, JavaScript, and DuckDB A5
  implementations.
- **vctrs + wk integration** — cell indices use an `a5_cell` type with
  tibble support; geometries return as `wk_wkb`/`wk_wkt` vectors
  compatible with sf and terra.
- **Grid generation** —
  [`a5_grid()`](https://belian-earth.github.io/a5R/reference/a5_grid.md)
  fills any bounding box or geometry with cells at a target resolution
  using hierarchical flood-fill.
- **Traversal** —
  [`a5_grid_disk()`](https://belian-earth.github.io/a5R/reference/a5_grid_disk.md)
  and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/reference/a5_spherical_cap.md)
  select neighbours by hop count or great-circle distance.
- **Multi-threading** — opt-in parallel processing via rayon for
  vectorised operations. See
  [`vignette("multithreading")`](https://belian-earth.github.io/a5R/articles/multithreading.md).

## Acknowledgements

A5 was created by [Felix Palmer](https://github.com/felixpalmer). This
package is a thin R wrapper around his work and would not exist without
it. The [Query-farm](https://github.com/Query-farm/a5) team maintain the
DuckDB A5 extension, which wraps the same Rust crate and provided a
valuable reference for this project.
