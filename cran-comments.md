## R CMD check results

Duration: 1m 52.9s

❯ checking for future file timestamps ... NOTE
  unable to verify current time

❯ checking compilation flags used ... NOTE
  Compilation used the following non-portable flag(s):
    ‘-mno-omit-leaf-frame-pointer’

0 errors ✔ | 0 warnings ✔ | 2 notes ✖

* This is a follow-up to the initial CRAN release (0.2.0). The main change
  is a new internal representation for `a5_cell` that stores cell IDs as
  eight raw-byte fields instead of hex strings, reducing memory by ~10x and
  eliminating hex parsing overhead at the R/Rust boundary. This redesign
  was developed in collaboration with Felix Palmer, maintainer of the
  upstream A5 Rust crate.
