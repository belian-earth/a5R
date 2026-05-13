## R CMD check results


Duration: 42.8s

❯ checking compilation flags used ... NOTE
  Compilation used the following non-portable flag(s):
    ‘-mno-omit-leaf-frame-pointer’

0 errors ✔ | 0 warnings ✔ | 1 note ✖

* This release adds two new geometry-to-cell indexing functions
  (`a5_polygon_to_cells()` and `a5_linestring_to_cells()`), both backed
  by the upstream a5 Rust crate (0.8.0). `a5_polygon_to_cells()` handles
  `POLYGON`, `MULTIPOLYGON`, and `sfc` inputs natively, with hole rings
  properly subtracted from their outer ring's cells. `a5_linestring_to_cells()`
  traces great-circle polylines and accepts `LINESTRING`, `MULTILINESTRING`,
  and `sfc` inputs.
* `a5_grid()` is soft-deprecated in favour of `a5_polygon_to_cells()` via
  `lifecycle::deprecate_warn()`. It still works; the warning points users
  to the replacement and notes the semantic difference (boundary
  intersection vs centre-in-polygon containment).
* `a5_cell_to_lonlat()` replaces its `normalise` argument with
  `as_dataframe`. The default behaviour is unchanged (returns a
  `wk::xy()` vector). The previous `normalise` argument toggled
  longitude normalisation, but upstream a5 (>= 0.7.3) always returns
  normalised longitudes, so the flag's effective job collapsed to
  selecting the return container. Explicit `normalise = ...` calls now
  error.
* The embedded Rust crate (a5) is bumped from 0.7.0 to 0.8.0, inheriting
  several upstream fixes (resolution-30 (de)serialisation, neighbour
  functions at resolutions 0 and 1, longitude normalisation in
  `cell_to_lonlat`, polar-region stability in `grid_disk` and
  `spherical_cap`, and faster `cell_to_parent`).
