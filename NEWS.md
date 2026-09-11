# a5R (development version)

* Reduced per-call overhead across the package. Rust output is wrapped
  without re-validation, cell fields are passed to Rust without building a
  data frame and read there without R-level `$` calls, scalar arguments are
  checked with a lightweight helper, `a5_lonlat_to_cell()` casts and
  recycles common inputs without vctrs, `a5_cell_to_lonlat()` uses
  low-level `wk` and data frame constructors, and `a5_cell_area()`,
  `a5_cell_edge_length_avg()` and `a5_cell_distance()` cache the parsed base
  unit. Scalar calls are three to twenty times faster; results, recycling
  rules and error messages are unchanged.

# a5R 0.6.0

* Updated the bundled 'A5' Rust crate to 0.10.0. The lattice curve is now
  laid out with an L-system and the equal-area projection is more
  efficient; upstream reports large speed-ups for `a5_polygon_to_cells()`,
  `a5_grid_disk()`, `a5_spherical_cap()` and `a5_cell_to_lonlat()`. Cell
  identifiers are unchanged: all existing results and snapshots are
  bit-for-bit identical.
* `a5_polygon_to_cells()` gains a `containment` argument. The default,
  `"centre"`, keeps the existing centre-in-polygon behaviour. The new
  `"overlapping"` mode additionally returns every cell that touches the
  polygon boundary, giving gap-free coverage; the result is a superset of
  the centre set. Hole interiors are still excluded in both modes. This
  restores the boundary-intersection use case previously served by the
  removed `a5_grid()`.
* New `a5_cell_edge_length_avg()` returns the average edge length of a cell
  at a given resolution, as a `units` vector (metres by default). Individual
  edges vary from the average by roughly +/-10%.

# a5R 0.5.0

* Removed `a5_grid()`, deprecated since 0.4.0. Use `a5_polygon_to_cells()`
  instead. Note the semantics differ: `a5_grid()` selected every cell a
  geometry touched (boundary intersection), whereas `a5_polygon_to_cells()`
  selects cells whose centre lies inside the geometry. For a bounding box,
  pass a closed polygon, e.g.
  `a5_polygon_to_cells(wk::rct(xmin, ymin, xmax, ymax), res)`.
* Dropped the `lifecycle` R dependency and the `wkt` Rust dependency, both
  of which were only needed by `a5_grid()`.
* Replaced the heavy `geo` Rust dependency with the lightweight
  `geographiclib-rs` crate for `a5_cell_distance()`. The haversine and
  rhumb methods are now computed directly; the geodesic method continues to
  use Karney's algorithm. Distance results are unchanged. This removes 33
  transitive crates and shrinks the vendored sources substantially.
* Updated the bundled 'A5' Rust crate to 0.9.0, bringing a faster
  polyhedral projection and an `EqualAreaProjection` refactor.
* `a5_polygon_to_cells()` now delegates hole handling to the upstream
  crate, which excludes hole interiors natively rather than subtracting
  hole-ring cells in R. Results are unchanged; the implementation is
  simpler and avoids an uncompact/recompact round-trip for single-part
  polygons.

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
  (including `MULTIPOLYGON` and `sfc` of several polygons), terra
  `SpatVector` objects, numeric matrices, or `data.frame(lon, lat)`.
  Multi-part inputs are handled natively: per polygon part the outer
  ring's cells are computed and any hole-ring cells are subtracted,
  then the results are unioned across parts and recompacted.
* New `a5_linestring_to_cells()` returns the A5 cells whose pentagons
  are intersected by a great-circle polyline, in discovery order along
  the path. Accepts the same input shapes as `a5_polygon_to_cells()`,
  including `MULTILINESTRING`, `sfc`s of multiple linestrings, and
  terra `SpatVector` objects; per-feature outputs are concatenated
  with first-seen deduplication.
* Bumped the embedded `a5` Rust crate from 0.7.0 to 0.8.0. Transparent
  improvements inherited from upstream: resolution-30 (de)serialisation
  (a5 0.7.1), neighbour functions at resolutions 0 and 1 (a5 0.7.2),
  longitude normalisation in `cell_to_lonlat` (a5 0.7.3), faster
  `cell_to_parent`, and a polar-region spiral fix in `grid_disk` and
  `spherical_cap`.
* **Breaking:** `a5_cell_to_lonlat()` replaces its `normalise` argument
  with `as_dataframe` (default `FALSE`). When `FALSE`, centroids are
  returned as a `wk::xy()` vector with WGS 84 CRS; when `TRUE`, as a
  base `data.frame` with `lon`/`lat` columns. The previous `normalise`
  argument toggled longitude normalisation, but upstream a5 (>= 0.7.3)
  always returns normalised longitudes, so the flag's effective job
  collapsed to "what container?". `as_dataframe` makes that explicit.
  Defaults are unchanged for users who never set `normalise` (still
  returns `wk::xy`); explicit `normalise = TRUE`/`FALSE` calls now
  error and must be updated.
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
