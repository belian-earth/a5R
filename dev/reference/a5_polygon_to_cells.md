# Cells inside or overlapping a polygon

Returns, for each polygon feature, an
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
of the A5 cells at `resolution` that belong to it. By default a cell
belongs when its centre lies inside the polygon; set
`containment = "overlapping"` to also include every cell that touches
the polygon boundary, giving gap-free coverage.

## Usage

``` r
a5_polygon_to_cells(x, resolution, containment = c("centre", "overlapping"))
```

## Arguments

- x:

  A polygon-like geometry. One of:

  - Any geometry handleable by
    [`wk::wk_handle()`](https://paleolimbot.github.io/wk/reference/wk_handle.html)
    (e.g.
    [`wk::wkt()`](https://paleolimbot.github.io/wk/reference/wkt.html),
    [`wk::wkb()`](https://paleolimbot.github.io/wk/reference/wkb.html),
    [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html),
    `sf`, `sfc`) containing one or more `POLYGON` / `MULTIPOLYGON`
    features.

  - A `SpatVector` of polygons (requires the `terra` package).

  - A two-column numeric matrix (`cbind(lon, lat)`) of vertices,
    interpreted as a single outer ring.

  - A `data.frame` with columns `lon` and `lat`, interpreted as a single
    outer ring.

- resolution:

  Integer scalar target resolution (0-30).

- containment:

  Character scalar selecting which cells to include. `"centre"` (the
  default; `"center"` also works) includes a cell when its centre lies
  inside the polygon. `"overlapping"` additionally includes every cell
  that overlaps the polygon boundary, so the result fully covers the
  polygon. The overlapping set is a superset of the centre set.

## Value

An
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vector with one element per feature (one for matrix and `data.frame`
input). `NA` for a missing geometry; an empty covering for an empty
geometry or one too small to hold a cell centre.

## Details

The result has one covering per feature, so it can be added as a column:
`sf_data$cells <- a5_polygon_to_cells(sf_data, 10)`. A feature's parts
(a `MULTIPOLYGON`) and holes are combined into its covering, with hole
interiors excluded. To combine features into one covering, use
[`a5_union()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md).
Coverings are compacted; use
[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
for the cells at `resolution`.

With `containment = "centre"`, membership is determined by
**centre-point containment**: a cell is included if its centroid lies
inside the polygon, with hole interiors excluded. Cells straddling the
boundary whose centre falls outside are dropped, so the union of the
cells does not fully cover the polygon.

With `containment = "overlapping"`, every cell that contains any point
of the polygon boundary is kept as well, so the returned cells cover the
polygon without gaps. Hole boundaries count as boundary, so cells
straddling a hole edge are included while the hole interior is still
excluded.

Coordinates must be WGS 84 longitude/latitude in degrees. Rings are
closed automatically; a trailing duplicate vertex is dropped if present.
An outer ring with fewer than 3 distinct vertices gives an empty
covering, and a hole with fewer than 3 is ignored, as in the other A5
libraries.

Polygon edges are great-circle arcs, the shortest path on the sphere
between consecutive vertices, as in the other A5 libraries and in s2. An
edge between two points on the same parallel therefore bows toward the
pole: a 20 degree edge along 10 degrees north peaks at 10.15 degrees
north, and a 1 degree edge at that latitude bows by about 40 m. An edge
whose ends are antipodal has no single great circle and gives an
undefined result. Where edges should follow parallels, as in GeoJSON
(RFC 7946 defines its edges as straight in longitude and latitude), add
vertices along them first.

A [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html) box
is a polygon with great-circle edges like any other, with two
exceptions: a box covering the whole globe
(`wk::rct(-180, -90, 180, 90)`) gives every cell, and a box reaching
from pole to pole keeps its west and east edges on their meridians. Any
other box spanning 180 degrees of longitude or more is an error, because
its top and bottom edges would run the short way round the globe.

Rings must not cross themselves: a ring with two edges that cross, such
as a bow tie, is an error of class `a5R_error_geometry`. Repair such
rings first, for example with
[`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html).
Because edges are great circles, a ring that is valid in longitude and
latitude can still cross itself on the sphere;
[`s2::s2_is_valid()`](https://r-spatial.github.io/s2/reference/s2_is_collection.html)
checks rings with the same edge model. Rings that only touch themselves,
and holes that cross the outer ring, are not checked.

Where no A5 cell centroids at the specified `resolution` fall within the
geometry, its covering is empty.

Matrix and `data.frame` inputs are treated as a single ring; for
multi-feature data or polygons with holes, pass an `sf`, `sfc`, wk, or
`SpatVector` geometry instead.

## See also

[`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md),
[`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md).

## Examples

``` r
poly <- wk::wkt(
  "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))"
)
covering <- a5_polygon_to_cells(poly, resolution = 8)
covering
#> <a5_covering[1]>
#> [1] res 8: empty
a5_uncompact(covering)
#> <a5_cell[0]>

# Gap-free coverage: every cell touching the polygon
a5_polygon_to_cells(poly, resolution = 8, containment = "overlapping")
#> <a5_covering[1]>
#> [1] res 8: 2 cells (2 stored)

# One covering per feature
polys <- wk::wkt(c(
  "POLYGON ((-3.3 55.9, -3.1 55.9, -3.1 56, -3.3 56, -3.3 55.9))",
  NA,
  "POLYGON ((-4.3 55.8, -4.2 55.8, -4.2 55.9, -4.3 55.9, -4.3 55.8))"
))
a5_polygon_to_cells(polys, resolution = 8)
#> <a5_covering[3]>
#> [1] res 8: empty <NA>         res 8: empty
```
