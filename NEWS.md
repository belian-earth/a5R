# a5R 0.4.0

* `a5_grid()` is soft-deprecated in favour of `a5_polygon_to_cells()`.
  Calling it now emits a `lifecycle::deprecate_warn()` with guidance: use
  `a5_polygon_to_cells()` for geometry inputs (centre-in-polygon
  containment), or pass a `wk::rct()` bounding box for the bbox use
  case. Note that the two functions are not semantically identical:
  `a5_grid()` uses boundary intersection (any cell touched by the
  geometry), whereas `a5_polygon_to_cells()` uses centre-point
  containment (cells whose centroid lies inside).
* New `a5_polygon_to_cells()` returns the A5 cells whose centres lie
  inside a polygon. Distinct from `a5_grid()`, which uses
  boundary-intersection semantics. Accepts wk-handleable geometries
  (including `MULTIPOLYGON` and `sfc` of several polygons), numeric
  matrices, or `data.frame(lon, lat)`. Multi-part inputs are handled
  natively: per polygon part the outer ring's cells are computed and
  any hole-ring cells are subtracted, then the results are unioned
  across parts and recompacted.
* New `a5_linestring_to_cells()` returns the A5 cells whose pentagons
  are intersected by a great-circle polyline, in discovery order along
  the path. Accepts the same input shapes as `a5_polygon_to_cells()`,
  including `MULTILINESTRING` and `sfc`s of multiple linestrings;
  per-feature outputs are concatenated with first-seen deduplication.
* Bumped the embedded `a5` Rust crate from 0.7.0 to 0.8.0. Transparent
  improvements inherited from upstream: resolution-30 (de)serialisation
  (a5 0.7.1), neighbour functions at resolutions 0 and 1 (a5 0.7.2),
  longitude normalisation in `cell_to_lonlat` (a5 0.7.3), faster
  `cell_to_parent`, and a polar-region spiral fix in `grid_disk` and
  `spherical_cap`.
* `a5_cell_to_lonlat()` gains an `as_dataframe` argument (default
  `FALSE`) controlling whether centroids are returned as a `wk::xy()`
  vector (the default — geographic-typed with WGS 84 CRS) or as a
  `data.frame` with `lon`/`lat` columns. The previous `normalise`
  argument is soft-deprecated via `lifecycle::deprecate_warn()` and
  maps to the inverse of `as_dataframe`: `normalise = TRUE` →
  `as_dataframe = FALSE`. The rename reflects the new reality of the
  underlying a5 crate, where centroid longitudes are always normalised
  to \eqn{[-180, 180]} since a5 v0.7.3; the flag was misnamed for its
  actual job, which is selecting the return container.
* New `lifecycle` dependency added to `Imports`.

# a5R 0.3.1

* `a5_cell()` now requires hex strings to be exactly 16 characters,
  preventing silent construction of wrong cells from truncated input.
* Improved vignettes covering the new `a5_cell` representation and Arrow
  integration.

# a5R 0.3.0

* `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell (#12).
* `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling `sort()`, `order()`, `unique()`, `duplicated()`, `match()`,
  and `%in%` (#12).
* `a5_cell` gains an `is.na()` method (#12).
* New `a5_cell_from_arrow()` and `a5_cell_to_arrow()` for lossless
  conversion between `a5_cell` and Arrow `uint64` arrays, enabling
  zero-copy Parquet I/O (#12).
* New `a5_u64_to_hex()` and `a5_hex_to_u64()` for explicit conversion
  between `a5_cell` vectors and hex strings.
* `a5_is_cell()` has been renamed to `a5_is_valid()` and now accepts
  both `a5_cell` vectors and character hex strings.
* `a5_cell_distance()` and `a5_cell_area()` gain a `units = NULL`
  option to return plain numeric vectors without `units` class
  overhead.
* New vignettes: `vignette("internal-cell-representation")` and
  `vignette("arrow-parquet")`.

# a5R 0.2.0

* Initial CRAN submission.
