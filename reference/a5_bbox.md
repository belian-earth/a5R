# Bounding box of polygons with great-circle edges

Returns, for each polygon feature, the longitude/latitude box that
contains its edges as A5 draws them: great circles between consecutive
vertices (see
[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_polygon_to_cells.md)).
Such an edge bows toward the pole, so the box can extend beyond the
latitudes of the vertices, which a plain vertex bounding box would miss.
A ring that winds around a pole extends the box to that pole across all
longitudes.

## Usage

``` r
a5_bbox(x)
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

## Value

A [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html)
vector with one box per feature (one for matrix and `data.frame` input),
in WGS 84 longitude and latitude. `NA` for a missing or empty geometry.

## Details

Longitudes are continuous: a box crossing the antimeridian has `xmin`
between -180 and 180 and `xmax` above 180.

## See also

[`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_polygon_to_cells.md)

## Examples

``` r
# an edge along 60 degrees north bows toward the pole
poly <- wk::wkt("POLYGON ((-30 50, 30 50, 30 60, -30 60, -30 50))")
a5_bbox(poly)
#> <wk_rct[1] with CRS=OGC:CRS84>
#> [1] [-30 50 30 63.43495]
wk::wk_bbox(poly)
#> <wk_rct[1]>
#> [1] [-30 50 30 60]
```
