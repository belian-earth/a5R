# List of A5 cell vectors

[`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md),
[`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
and
[`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
return an `a5_cell_list` when called with `simplify = FALSE`: a
[`vctrs::list_of()`](https://vctrs.r-lib.org/reference/list_of.html)
holding one
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector per input, usable as a list column. It behaves as any list:
[`lengths()`](https://rdrr.io/r/base/lengths.html) gives the number of
cells per input, `[[` extracts one element, and
[`tidyr::unnest()`](https://tidyr.tidyverse.org/reference/unnest.html)
expands it to one row per cell.

## Usage

``` r
as_a5_cell_list(x)

# S3 method for class 'a5_cell_list'
unlist(x, recursive = TRUE, use.names = TRUE)
```

## Arguments

- x:

  An `a5_cell_list`, or for `as_a5_cell_list()` a list of
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vectors.

- recursive, use.names:

  Ignored.

## Value

[`unlist()`](https://rdrr.io/r/base/unlist.html) returns an
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector.

## Details

[`unlist()`](https://rdrr.io/r/base/unlist.html) concatenates the
elements into a single
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector, equivalent to
[`vctrs::list_unchop()`](https://vctrs.r-lib.org/reference/list_unchop.html).
Without this method base
[`unlist()`](https://rdrr.io/r/base/unlist.html) would descend into the
raw byte fields of the record and return a meaningless raw vector. The
`recursive` and `use.names` arguments are accepted for compatibility and
ignored.

`as_a5_cell_list()` wraps a plain list of
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vectors (for example the output of
[`lapply()`](https://rdrr.io/r/base/lapply.html)) so that
[`unlist()`](https://rdrr.io/r/base/unlist.html) works on it. Elements
that are hex strings are converted; `NULL` elements become empty.

## Examples

``` r
cells <- a5_lonlat_to_cell(c(-3.19, 0), c(55.95, 0), resolution = 5)
lst <- a5_cell_to_children(cells, simplify = FALSE)
lengths(lst)
#> [1] 4 4
unlist(lst)
#> <a5_cell[8]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000
#> [5] 4f04800000000000 4f05800000000000 4f06800000000000 4f07800000000000

# lapply() produces a plain list, on which base unlist() would return raw
# bytes; wrap it first.
plain <- lapply(seq_along(cells), function(i) a5_cell_to_children(cells[i]))
unlist(as_a5_cell_list(plain))
#> <a5_cell[8]>
#> [1] 633c800000000000 633d800000000000 633e800000000000 633f800000000000
#> [5] 4f04800000000000 4f05800000000000 4f06800000000000 4f07800000000000
```
