
<!-- README.md is generated from README.Rmd. Please edit that file -->

# a5R

<!-- badges: start -->

[![R-CMD-check](https://github.com/belian-earth/a5R/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/belian-earth/a5R/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/belian-earth/a5R/graph/badge.svg)](https://app.codecov.io/gh/belian-earth/a5R)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

a5R provides R bindings for the [A5](https://a5geo.org/) pentagonal
discrete global grid system (DGGS), powered by the [a5 Rust
crate](https://crates.io/crates/A5) via
[extendr](https://extendr.github.io/extendr/extendr_api/).

A5 partitions the Earth’s surface into pentagonal cells across 31
resolution levels. Cells are equal-area, encoded as 64-bit integers, and
achieve millimetre-level precision at the finest resolution. For a full
description of the system, see the [A5 project page](https://a5geo.org/)
and the [reference implementation](https://github.com/felixpalmer/a5) by
Felix Palmer.

## R-specific design

- **vctrs**: Cell indices are represented as an `a5_cell` vector type
  built on [vctrs](https://vctrs.r-lib.org/), giving you type safety,
  column support in tibbles, and natural coercion to/from character.
- **wk**: Boundary geometries and cell centroids are returned as
  [wk](https://paleolimbot.github.io/wk/) geometry vectors (`wk_wkt` and
  `xy`), so they integrate directly with sf, terra, and other spatial
  tooling.

## Installation

You can install the development version of a5R from
[GitHub](https://github.com/belian-earth/a5R) with:

``` r
# install.packages("pak")
pak::pak("belian-earth/a5R")
```

You will need a working [Rust toolchain](https://rustup.rs/) (`cargo`
and `rustc`).

## Examples

``` r
library(a5R)
```

Index a point to a cell at resolution 5:

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
cell
#> <a5_cell[1]>
#> [1] 633e000000000000
```

Convert back to coordinates:

``` r
a5_cell_to_lonlat(cell)
#> <wk_xy[1] with CRS=OGC:CRS84>
#> [1] (-3.280745 56.43135)
```

Get the cell boundary as a WKT polygon:

``` r
a5_cell_to_boundary(cell)
#> <wk_wkt[1] with CRS=OGC:CRS84>
#> [1] POLYGON ((-4.490769 56.63193, -4.575103 55.93184, -4.654266 55.23196, -3.592316 55.41531, -2.521971 55.5901, -2.031558 56.23106...
```

Navigate the hierarchy:

``` r
a5_cell_to_parent(cell)
#> <a5_cell[1]>
#> [1] 6338000000000000
a5_cell_to_children(cell)
#> <a5_cell[4]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000
```

Cell info:

``` r
a5_get_resolution(cell)
#> [1] 5
a5_cell_area(0:5)
#> Units: [m^2]
#> [1] 4.250547e+13 8.501094e+12 2.125273e+12 5.313184e+11 1.328296e+11
#> [6] 3.320740e+10
```

### Visualising the grid hierarchy

``` r
# A cell and its children two levels down
parent <- a5_lonlat_to_cell(0, 0, resolution = 3)
children <- a5_cell_to_children(parent, resolution = 5)

# wk geometries plot directly with base graphics
plot(a5_cell_to_boundary(children), col = "#206ead20", border = "#206ead", asp = 1)
plot(a5_cell_to_boundary(parent), border = "#333333", lwd = 2, add = TRUE)
```

<img src="man/figures/README-hierarchy-plot-1.png" alt="Pentagonal A5 grid cells at two resolutions nested inside each other" width="100%" />

## Acknowledgements

A5 was created by [Felix Palmer](https://github.com/felixpalmer). This
package is a thin R wrapper around his work and would not exist without
it.
