## Submission

This release moves to the A5 1.0 cell index (the 'a5' Rust crate 1.0.0).
A5 1.0 renumbers every cell, so ids written by earlier versions of a5R
change. The new `a5_migrate()` converts stored ids, and NEWS.md describes
the change.

## R CMD check results

Local (Ubuntu 24.04, R 4.6.1, `--as-cran`), on the development version:
0 errors | 0 warnings | 2 notes. One NOTE flags the development version
number, which 1.0.0 replaces; the other a compiler flag set by the local R
installation.

<!-- TODO: rerun after use_version(), and add win-builder (devel) and R-hub -->

## Rust

The package bundles its Rust dependencies in `src/rust/vendor.tar.xz` and
builds offline with `cargo build -j 2 --offline`. Nothing is written to the
user's home directory. The minimum supported rustc version is 1.82.0,
declared in SystemRequirements, checked at configure time and tested.
Authors and licences of the bundled crates are listed in LICENSE.note.

## revdepcheck results

We checked 1 reverse dependency (pycnogrid), comparing R CMD check results
across CRAN and dev versions of this package.

 * We saw 0 new problems
 * We failed to check 0 packages

<!-- TODO: rerun revdepcheck::revdep_check() at release, and say here that
the pycnogrid maintainer has been told about the id change -->
