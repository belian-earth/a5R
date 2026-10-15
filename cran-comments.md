## Submission

This release moves to the A5 1.0 cell index (the 'a5' Rust crate 1.0.0).
A5 1.0 renumbers every cell, so ids written by earlier versions of a5R
change. The new `a5_migrate()` converts stored ids, and NEWS.md describes
the change.

## R CMD check results

<!-- TODO: rerun at release with the final crate -->
0 errors | 0 warnings | 0 notes

## Rust

The package bundles its Rust dependencies in `src/rust/vendor.tar.xz` and
builds offline with `cargo build -j 2 --offline`. Nothing is written to the
user's home directory. The minimum supported rustc version is 1.82.0,
declared in SystemRequirements and checked at configure time. Authors and
licences of the bundled crates are listed in LICENSE.note.

## revdepcheck results

<!-- TODO: rerun revdepcheck::revdep_check() at release -->
We checked 1 reverse dependency (pycnogrid), comparing R CMD check results
across CRAN and dev versions of this package.

 * We saw 0 new problems
 * We failed to check 0 packages

<!-- TODO: tell the pycnogrid maintainer about the id change, then say so here -->
