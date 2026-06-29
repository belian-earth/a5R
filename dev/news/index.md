# Changelog

## a5R (development version)

- Updated the bundled ‘A5’ Rust crate to 0.9.0, bringing a faster
  polyhedral projection and an `EqualAreaProjection` refactor.
- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  now delegates hole handling to the upstream crate, which excludes hole
  interiors natively rather than subtracting hole-ring cells in R.
  Results are unchanged; the implementation is simpler and avoids an
  uncompact/recompact round-trip for single-part polygons.

## a5R 0.4.0

CRAN release: 2026-05-14

- [`a5_grid()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid.md)
  is soft-deprecated in favour of
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md).
  Calling it now emits a
  [`lifecycle::deprecate_warn()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html)
  with guidance: use
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  for geometry inputs (centre-in-polygon containment), or pass a
  [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html)
  bounding box for the bbox use case. Note that the two functions are
  not semantically identical:
  [`a5_grid()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid.md)
  uses boundary intersection (any cell touched by the geometry), whereas
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  uses centre-point containment (cells whose centroid lies inside).
- New
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  returns the A5 cells whose centres lie inside a polygon. Distinct from
  [`a5_grid()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid.md),
  which uses boundary-intersection semantics. Accepts wk-handleable
  geometries (including `MULTIPOLYGON` and `sfc` of several polygons),
  terra `SpatVector` objects, numeric matrices, or
  `data.frame(lon, lat)`. Multi-part inputs are handled natively: per
  polygon part the outer ring’s cells are computed and any hole-ring
  cells are subtracted, then the results are unioned across parts and
  recompacted.
- New
  [`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_linestring_to_cells.md)
  returns the A5 cells whose pentagons are intersected by a great-circle
  polyline, in discovery order along the path. Accepts the same input
  shapes as
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md),
  including `MULTILINESTRING`, `sfc`s of multiple linestrings, and terra
  `SpatVector` objects; per-feature outputs are concatenated with
  first-seen deduplication.
- Bumped the embedded `a5` Rust crate from 0.7.0 to 0.8.0. Transparent
  improvements inherited from upstream: resolution-30 (de)serialisation
  (a5 0.7.1), neighbour functions at resolutions 0 and 1 (a5 0.7.2),
  longitude normalisation in `cell_to_lonlat` (a5 0.7.3), faster
  `cell_to_parent`, and a polar-region spiral fix in `grid_disk` and
  `spherical_cap`.
- **Breaking:**
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_lonlat.md)
  replaces its `normalise` argument with `as_dataframe` (default
  `FALSE`). When `FALSE`, centroids are returned as a
  [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
  vector with WGS 84 CRS; when `TRUE`, as a base `data.frame` with
  `lon`/`lat` columns. The previous `normalise` argument toggled
  longitude normalisation, but upstream a5 (\>= 0.7.3) always returns
  normalised longitudes, so the flag’s effective job collapsed to “what
  container?”. `as_dataframe` makes that explicit. Defaults are
  unchanged for users who never set `normalise` (still returns
  [`wk::xy`](https://paleolimbot.github.io/wk/reference/xy.html));
  explicit `normalise = TRUE`/`FALSE` calls now error and must be
  updated.
- New `lifecycle` dependency added to `Imports`.

## a5R 0.3.1

CRAN release: 2026-03-26

- [`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  now requires hex strings to be exactly 16 characters, preventing
  silent construction of wrong cells from truncated input.
- Improved vignettes covering the new `a5_cell` representation and Arrow
  integration.

## a5R 0.3.0

- `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling [`sort()`](https://rdrr.io/r/base/sort.html),
  [`order()`](https://rdrr.io/r/base/order.html),
  [`unique()`](https://rdrr.io/r/base/unique.html),
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html),
  [`match()`](https://rdrr.io/r/base/match.html), and `%in%`
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- `a5_cell` gains an [`is.na()`](https://rdrr.io/r/base/NA.html) method
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- New
  [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  and
  [`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  for lossless conversion between `a5_cell` and Arrow `uint64` arrays,
  enabling zero-copy Parquet I/O
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- New
  [`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  and
  [`a5_hex_to_u64()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  for explicit conversion between `a5_cell` vectors and hex strings.
- `a5_is_cell()` has been renamed to
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  and now accepts both `a5_cell` vectors and character hex strings.
- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_area.md)
  gain a `units = NULL` option to return plain numeric vectors without
  `units` class overhead.
- New vignettes:
  [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/dev/articles/internal-cell-representation.md)
  and
  [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/dev/articles/arrow-parquet.md).

## a5R 0.2.0

CRAN release: 2026-03-16

- Initial CRAN submission.
