## Submission

This release moves to the A5 1.0 cell index (the 'a5' Rust crate 1.0.0).
A5 1.0 renumbers every cell, so ids written by earlier versions of a5R
change. The new `a5_migrate()` converts stored ids. Several functions are
renamed to match the other A5 libraries; the old names still work but warn.
NEWS.md lists the changes.

## R CMD check results

0 errors | 0 warnings | 1 note

* The note, seen only locally, flags a compiler flag set by the local R
  installation.

## revdepcheck results

We checked 1 reverse dependency (pycnogrid), comparing R CMD check results
across CRAN and dev versions of this package.

 * We saw 0 new problems
 * We failed to check 0 packages

We have told the pycnogrid maintainer about the cell-id change
(https://github.com/higgicd/pycnogrid/issues/3).
