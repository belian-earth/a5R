## R CMD check results

❯ checking compilation flags used ... NOTE
  Compilation used the following non-portable flag(s):
    ‘-mno-omit-leaf-frame-pointer’

0 errors ✔ | 0 warnings ✔ | 1 note ✖


This is a maintenance release that removes a deprecated function and 
reduces the package's dependency footprint.

* Removed `a5_grid()`. It was soft-deprecated in 0.4.0 via
  `lifecycle::deprecate_warn()` and superseded by `a5_polygon_to_cells()`.
  This is a breaking change. The two functions differ in semantics
  (`a5_grid()` used boundary intersection; `a5_polygon_to_cells()` uses
  centre-in-polygon containment), which the 0.4.0 deprecation warning
  documented.
* Dropped two dependencies that were only required by `a5_grid()`: the
  `lifecycle` R package (removed from Imports) and the `wkt` Rust crate.
* Replaced the `geo` Rust crate with the lighter `geographiclib-rs` crate
  for `a5_cell_distance()`. The haversine and rhumb methods are now
  computed directly; the geodesic method continues to use Karney's
  algorithm. Distance results are unchanged. This removes 33 transitive
  Rust dependencies and reduces the vendored sources from roughly 3.0 MB
  to 1.0 MB.
* Bumped the embedded `a5` Rust crate from 0.8.0 to 0.9.0, which handles
  polygon holes natively in `a5_polygon_to_cells()` and brings upstream
  projection improvements.

