# Generate a grid of A5 cells covering an area

Returns all cells at the target resolution that intersect the given
geometry. Uses hierarchical flood-fill: starting from the 12
resolution-0 root cells, the algorithm repeatedly expands and prunes by
spatial intersection until the target resolution is reached.

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

The algorithm expands cells 3 resolution levels at a time (64x
expansion) and filters by intersection at each step, keeping the working
set small. At intermediate resolutions a spatial buffer is applied to
avoid pruning cells whose children straddle the target boundary (A5
cells are not strictly geometrically nested across resolutions). The
final step uses exact
[`geos::geos_intersects()`](https://paleolimbot.github.io/geos/reference/geos_disjoint.html)
filtering.

No artificial cell count limit is imposed. High resolution combined with
a large area can produce very large results and consume significant
memory.

In addition to numeric bounding boxes, `x` accepts any geometry that
[`geos::as_geos_geometry()`](https://paleolimbot.github.io/geos/reference/as_geos_geometry.html)
can handle, including `sf`/`sfc` objects,
[`wk::wkt()`](https://paleolimbot.github.io/wk/reference/wkt.html),
[`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html), and
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vectors. Multiple geometries are unioned automatically. Input geometries
are assumed to use WGS 84 (longitude/latitude) coordinates; projected
geometries are not reprojected and will produce incorrect results.

Antimeridian-crossing bounding boxes are supported: when `xmin > xmax`
in a numeric input (e.g. `c(170, -50, -170, -30)`), the bbox is
automatically split into two rectangles either side of the antimeridian.

**Known limitation:** spatial filtering uses planar geometry
([`geos::geos_intersects()`](https://paleolimbot.github.io/geos/reference/geos_disjoint.html))
on longitude/latitude coordinates. This can produce incomplete results
for target areas very close to the poles (above ~88° latitude) or
touching the antimeridian (longitude ±180°), where cell boundary
polygons do not accurately represent their true spherical coverage. For
these areas, use a larger target geometry to ensure complete coverage.

## See also

[`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_boundary.md)
to convert result cells to geometries.

## Examples

``` r
# Grid from a bounding box
cells <- a5_grid(c(-3.3, 55.9, -3.1, 56.0), resolution = 5)
cells
#> <a5_cell[1]>
#> [1] 633e000000000000

# Grid from a WKT polygon
poly <- wk::wkt("POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))")
cells <- a5_grid(poly, resolution = 5)
```
