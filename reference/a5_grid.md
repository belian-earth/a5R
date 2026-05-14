# **\[deprecated\]**

Generate a grid of A5 cells covering an area

## Usage

``` r
a5_grid(x, resolution)
```

## Arguments

- x:

  An area specification. One of:

  - A numeric vector of length 4 (`c(xmin, ymin, xmax, ymax)`)
    interpreted as a WGS 84 bounding box.

  - Any geometry handleable by
    [`wk::wk_handle()`](https://paleolimbot.github.io/wk/reference/wk_handle.html)
    (e.g.
    [`wk::wkt()`](https://paleolimbot.github.io/wk/reference/wkt.html),
    [`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html),
    `sfc`, `sf`,
    [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)).

- resolution:

  Integer scalar target resolution (0–30).

## Value

An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector of cells at `resolution` that intersect `x`.

## Details

Returns all cells at the target resolution that intersect the given
geometry. Uses hierarchical flood-fill: starting from the 12
resolution-0 root cells, the algorithm repeatedly expands and prunes by
spatial intersection until the target resolution is reached.

Grid generation runs entirely in Rust via hierarchical flood-fill with
bounding-box pruning. For non-bbox geometry inputs, an exact
intersection filter removes cells that fall outside the target shape. No
cell count limit is imposed — high resolutions over large areas can
consume significant memory.

Input geometries must use WGS 84 coordinates; projected geometries are
not reprojected and will produce incorrect results. Multiple geometries
are collected into a GEOMETRYCOLLECTION automatically.
Antimeridian-crossing bounding boxes are supported: when `xmin > xmax`
(e.g. `c(170, -50, -170, -30)`), the bbox is split at the antimeridian.

**Limitation:** spatial filtering uses planar geometry on lon/lat
coordinates, which can produce incomplete results very close to the
poles (above ~88° latitude) or the antimeridian. Use a larger target
geometry to ensure complete coverage in these areas.

## See also

[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_boundary.md)
to convert result cells to geometries.

## Examples

``` r
# Grid from a bounding box
cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 5)
#> Warning: `a5_grid()` was deprecated in a5R 0.4.0.
#> ℹ Please use `a5_polygon_to_cells()` instead.
#> ℹ `a5_polygon_to_cells()` uses centre-in-polygon containment, whereas
#>   `a5_grid()` uses boundary intersection. Results can differ for cells crossed
#>   by the polygon edge.
#> ℹ For a bounding box, build a closed polygon first, e.g.
#>   `a5_polygon_to_cells(wk::rct(xmin, ymin, xmax, ymax), res)`.
cells
#> <a5_cell[1]>
#> [1] 633e000000000000

# Grid from a WKT polygon
poly <- wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))")
cells <- a5_grid(poly, resolution = 5)
```
