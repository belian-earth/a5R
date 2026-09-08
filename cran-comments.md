## R CMD check results

❯ checking compilation flags used ... NOTE
  Compilation used the following non-portable flag(s):
    ‘-mno-omit-leaf-frame-pointer’

0 errors ✔ | 0 warnings ✔ | 1 note ✖

The NOTE is a local toolchain artefact: the flag comes from the system R
build's default CFLAGS on Ubuntu, not from the package.

## Reverse dependencies

There is one CRAN reverse dependency, `pycnogrid`. It calls
`a5_polygon_to_cells()` and `a5_cell_area()`, both of which are unchanged
apart from the additive argument described below. `R CMD check` on
`pycnogrid` with this version of a5R installed passes.

## Release notes

This is a feature release with no breaking changes.

* Bumped the embedded `a5` Rust crate from 0.9.0 to 0.10.0. The lattice
  curve is now laid out with an L-system and the equal-area projection is
  more efficient, giving substantial upstream speed-ups for polygon fill
  and traversal. Cell identifiers are unchanged; all existing tests and
  snapshots pass bit-for-bit.
* `a5_polygon_to_cells()` gains a `containment` argument. The default,
  `"centre"`, preserves the existing behaviour. `"overlapping"` also
  returns every cell touching the polygon boundary, giving gap-free
  coverage.
* New `a5_cell_edge_length_avg()` returns the average edge length of a
  cell at a given resolution as a `units` vector.
* No changes to R or system dependencies. The vendored Rust sources remain
  at roughly 1.0 MB.
