# Migrate cell ids from the pre-1.0 index

Converts cell ids written by a5R before 1.0 (the a5 Rust crate 0.10 and
earlier, the "v0" index) to the current, permanent index. A5 1.0 threads
its space-filling curve through the cells differently, so cells keep
their shape and position but get new ids. The conversion is a cheap bit
operation; there is no need to re-index data from its coordinates. The
exception is resolution 1, whose 60 cells changed from triangles to
pentagons: each migrated resolution-1 id is the new cell containing the
old cell's centre.

## Usage

``` r
a5_migrate(cell)
```

## Arguments

- cell:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector of ids in the v0 index.

## Value

An
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector of the same cells in the current index, the same length as
`cell`. `NA` where `cell` is `NA`.

## Details

A v0 id is still a valid cell in the current index, but in a different
place, and nothing in the id records which version wrote it. Migrate
stored ids exactly once, as soon as they are read: migrating current
ids, or migrating twice, gives wrong cells without any error.

Upstream will retire this conversion in a future version.

## See also

[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
to read stored ids.

## Examples

``` r
# A resolution-8 cell id from a5R 0.6.0
v0 <- a5_cell("59c4780000000000")
a5_migrate(v0)
#> <a5_cell[1]>
#> [1] 59c4280000000000
```
