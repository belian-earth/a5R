# Check that values are A5 cells

`a5_is_valid_cell()` checks each value against the A5 index encoding:
its resolution bits must name a resolution, and its face or quintant
must exist. Use it on ids from outside sources, such as a file or a
database, before passing them to other functions.
[`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
accepts any 16-digit hex string, so an `a5_cell` vector can hold values
that are not cells.

## Usage

``` r
a5_is_valid(x)

a5_is_valid_cell(x)
```

## Arguments

- x:

  An
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector or a character vector of hex strings. For `a5_is_valid()`, also
  an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  or an
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md).

## Value

A logical vector the length of `x`. `NA` where `x` is `NA`; for an
[a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md),
`NA` where an element holds `NA` and no invalid cell; for an
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md),
`NA` for a missing covering. Hex strings that are not 16 hex digits are
`FALSE`.

## Details

`a5_is_valid()` checks any a5R object, returning one value per element:

- an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector or hex strings: whether each value is a cell, as
  `a5_is_valid_cell()`.

- an
  [a5_cell_list](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md):
  whether every cell in each element is valid. An empty element is
  valid.

- an
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md):
  whether each covering is well formed: every stored value but a
  trailing compaction marker is a valid cell, no cell is finer than the
  covering's resolution, and the cells are sorted in curve order without
  overlapping. a5R always builds coverings this way; the check is for
  coverings assembled by hand, as the covering functions rely on it. A
  covering need not be fully compacted to be valid.

The world cell (id 0, resolution -1) is valid: it has no boundary, but
[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
returns it as the parent of the resolution-0 cells. Validity says
nothing about which index version an id was written with: ids from a5R
before 1.0 are valid cells in a different place. See
[`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md).

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
a5_is_valid_cell(cell)
#> [1] TRUE
a5_is_valid_cell(c(a5_u64_to_hex(cell), "fd00000000000000", "not_a_cell", NA))
#> [1]  TRUE FALSE FALSE    NA

a5_is_valid(a5_cell_to_children(cell, simplify = FALSE))
#> [1] TRUE
```
