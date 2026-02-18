# Getting started with a5R

``` r
library(a5R)
```

## Index a point

Map a longitude/latitude coordinate to a cell at a given resolution
(0–30). Higher resolutions produce smaller cells.

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
cell
#> <a5_cell[1]>
#> [1] 633e000000000000
```

Convert back to the cell centre point:

``` r
a5_cell_to_lonlat(cell)
#> <wk_xy[1] with CRS=OGC:CRS84>
#> [1] (-3.280745 56.43135)
```

## Cell boundaries

Get the boundary polygon for one or more cells:

``` r
boundary <- a5_cell_to_boundary(cell)
boundary
#> <wk_wkb[1] with CRS=OGC:CRS84>
#> [1] <POLYGON ((-4.490769 56.63193, -4.575103 55.93184, -4.654266 55.23196, -3.592316 55.41531, -2.521971 55.5901, -2.031558 56.23106...>

plot(boundary, col = "#206ead20", border = "#206ead", asp = 1)
```

![](a5R_files/figure-html/boundary-plot-1.png)

Boundaries are returned as `wk_wkb` vectors by default (set
`format = "wkt"` for WKT). Both integrate directly with sf, terra, and
other spatial tooling via the wk package.

## Hierarchy

Every cell has a parent at a coarser resolution and children at finer
resolutions. A5 cells have 4 children per level.

``` r
a5_cell_to_parent(cell)
#> <a5_cell[1]>
#> [1] 6338000000000000
children <- a5_cell_to_children(cell)
children
#> <a5_cell[4]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000
```

Cell area decreases geometrically with resolution:

``` r
a5_cell_area(0:5)
#> Units: [m^2]
#> [1] 4.250547e+13 8.501094e+12 2.125273e+12 5.313184e+11 1.328296e+11
#> [6] 3.320740e+10
```

## Grid generation

[`a5_grid()`](https://belian-earth.github.io/a5R/reference/a5_grid.md)
returns all cells at a target resolution that cover a given area. Pass a
bounding box as a numeric vector:

``` r
cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 8)
length(cells)
#> [1] 3

plot(a5_cell_to_boundary(cells), col = "#206ead20", border = "#206ead", asp = 1)
```

![](a5R_files/figure-html/grid-plot-1.png)

Any geometry that wk can handle works too — polygons, sf objects, or
even `a5_cell` vectors:

``` r
poly <- wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))")
a5_grid(poly, resolution = 5)
#> <a5_cell[1]>
#> [1] 633e000000000000
```

## Compact and uncompact

When a complete set of siblings is present,
[`a5_compact()`](https://belian-earth.github.io/a5R/reference/a5_compact.md)
merges them into their shared parent, reducing the number of cells
without losing coverage:

``` r
children <- a5_cell_to_children(cell)
length(children)
#> [1] 4

compacted <- a5_compact(children)
compacted
#> <a5_cell[1]>
#> [1] 633e000000000000

# Round-trip back to the original set
a5_uncompact(compacted, resolution = 6)
#> <a5_cell[4]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000
```
