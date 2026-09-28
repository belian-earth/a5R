# How a5R stores cell IDs without strings

## The problem

An A5 cell ID is a 64-bit unsigned integer (`u64`). R has no native
`u64` type: its integers are 32-bit signed (`-2^31` to `2^31 - 1`), and
its doubles are 64-bit floating point. A `double` can only represent
integers exactly up to 2^53, while a `u64` can go up to 2^64 - 1.

The obvious workaround is to store cell IDs as hex strings
(`"0800000000000006"`). This works, but every trip across the R / Rust
boundary requires hex parsing and formatting: O(n) string allocation
that dominates the cost of lightweight operations like
[`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md)
or
[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md).

## The solution: eight raw-byte fields

A `u64` is exactly 8 bytes. We store each byte of the little-endian
representation as a separate `raw` vector field in a vctrs record type,
with one twist: the most significant byte, `b8`, is stored XOR `0xFC`
(see [NA handling](#na-handling) for why).

    cell_id (u64):  0x0800000000000006

    little-endian bytes:
      0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08

    stored fields:
      b1 = 0x06, b2 = 0x00, b3 = 0x00, b4 = 0x00,
      b5 = 0x00, b6 = 0x00, b7 = 0x00, b8 = 0x08 XOR 0xFC = 0xF4

This is lossless: XOR with a constant is its own inverse, so the eight
stored bytes map one-to-one onto the original `u64`. On the Rust side,
reconstructing the id from the eight byte slices is one XOR and a single
`u64::from_le_bytes()` call. There are no pointers, so an `a5_cell` can
be saved with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) like
any other R object. Objects saved by a5R 0.6.0 or earlier used the plain
byte layout and do not read correctly in later versions; re-create them
from hex strings or Arrow, which store the true id.

## R-side: a vctrs record type

On the R side, `a5_cell` is a **vctrs record**
([`vctrs::new_rcrd()`](https://vctrs.r-lib.org/reference/new_rcrd.html))
with eight fields (`b1` through `b8`):

``` r

library(a5R)
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
vctrs::field(cell, "b1")
#> [1] 00
vctrs::field(cell, "b8") # stored XOR 0xFC
#> [1] 9f
```

Each field is a plain `raw` vector: a contiguous block of memory with no
per-element overhead. Subsetting, combining, and NA propagation are all
handled automatically by vctrs.

Hex strings are only produced on demand:

``` r

# Display calls format(), which converts to hex for readability
cell
#> <a5_cell[1]>
#> [1] 6344be8000000000

# Explicit conversion
a5_u64_to_hex(cell)
#> [1] "6344be8000000000"

# Round-trip from hex
a5_cell("0800000000000006")
#> <a5_cell[1]>
#> [1] 0800000000000006
```

## Why this matters

Compare memory for one million cells:

``` r

set.seed(42)
cells <- a5_lonlat_to_cell(
  runif(1e6, -180, 180),
  runif(1e6, -80, 80),
  resolution = 10
)

# rcrd: eight contiguous raw vectors (8 × 1 byte × 1M ≈ 7.6 MB)
format(object.size(cells), units = "MB")
#> [1] "7.6 Mb"

# equivalent hex strings would be ~81 MB
# (16 chars + 56-byte SEXP header per string)
hex <- a5_u64_to_hex(cells)
format(object.size(hex), units = "MB")
#> [1] "81 Mb"
```

## NA handling

`NA` is the id `0xFC00000000000000`. It is never a valid cell: at
resolutions 0 to 29 the top 6 bits hold the quintant (0 to 59), and 63
(binary `111111`) is unused; the id does not decode as a resolution-30
cell either. Only the full id is the sentinel. Resolution 30 keeps just
5, 3 or 1 quintant bits at the top to make room for position bits, so
valid resolution-30 cells can have a top byte of `0xFC`.

Storing `b8` XOR `0xFC` makes the sentinel’s stored form eight `00`
bytes. That matters because vctrs fills gaps field by field, and a
missing `raw` value is `00`. Combining with `NA`, subsetting with an
`NA` index, assigning `NA`, and unmatched rows in joins all produce
eight `00` bytes, which decode to `NA`. With plain bytes they would
decode to id 0, the world cell, a valid id.

On the Rust side, the sentinel is detected and mapped to `None`.
Standard R idioms work as expected:

``` r

cells_with_na <- a5_cell(c("0800000000000006", NA))
is.na(cells_with_na)
#> [1] FALSE  TRUE
is.na(c(cell, NA))
#> [1] FALSE  TRUE
```

## Working with base R

Because an `a5_cell` is a list of eight raw fields underneath, base
functions that look at that structure directly rather than dispatching
on the class need some care. a5R covers the common cases; the rest have
a vctrs form that is both correct and fast.

**Works as expected.** Subsetting,
[`c()`](https://rdrr.io/r/base/c.html),
[`rev()`](https://rdrr.io/r/base/rev.html),
[`unique()`](https://rdrr.io/r/base/unique.html),
[`duplicated()`](https://rdrr.io/r/base/duplicated.html),
[`sort()`](https://rdrr.io/r/base/sort.html),
[`order()`](https://rdrr.io/r/base/order.html),
[`is.na()`](https://rdrr.io/r/base/NA.html),
[`sample()`](https://rdrr.io/r/base/sample.html), `==`, comparison
operators, `split(cells, f)` with a factor `f`, data frame and tibble
columns, and [`rbind()`](https://rdrr.io/r/base/cbind.html) of data
frames with `a5_cell` columns. Assigning past the end
(`x[length(x) + 1] <- cell`) and `length(x) <- n` grow the vector with
`NA`, as they do for base vectors.

**Fast.** [`match()`](https://rdrr.io/r/base/match.html) and `%in%` use
an exact [`mtfrm()`](https://rdrr.io/r/base/mtfrm.html) key rather than
hex strings, so they cost about the same as
[`vctrs::vec_match()`](https://vctrs.r-lib.org/reference/vec_match.html)
and
[`vctrs::vec_in()`](https://vctrs.r-lib.org/reference/vec_match.html).

**Use the vctrs form instead.** Three base cases cannot be intercepted
by a method:

- [`c()`](https://rdrr.io/r/base/c.html) dispatches on its first
  argument only, so `c(NA, cells)` with a bare `NA` first never reaches
  the `a5_cell` method and returns a list. Base classes behave the same
  way: `c(NA, Sys.Date())` loses the `Date` class. Start with a cell, as
  in `c(a5_cell(NA), cells)`, or use `vctrs::vec_c(NA, cells)`, which
  combines by every argument’s type. An `NA` anywhere after the first
  argument is fine.

- `split(x, cells)` and `tapply(x, cells, f)` with an `a5_cell`
  *grouping* vector see a list of eight raw vectors and group on their
  interaction, giving one group or an error. Use
  `vctrs::vec_split(x, cells)` or `vctrs::vec_group_id(cells)`, or group
  with `factor(cells)`.

- [`unlist()`](https://rdrr.io/r/base/unlist.html) on a plain list of
  `a5_cell` vectors, such as
  [`lapply()`](https://rdrr.io/r/base/lapply.html) output, descends into
  the fields and returns a meaningless `raw` vector. Use
  [`vctrs::list_unchop()`](https://vctrs.r-lib.org/reference/list_unchop.html),
  `do.call(c, x)`, or wrap the list with
  [`as_a5_cell_list()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md),
  after which [`unlist()`](https://rdrr.io/r/base/unlist.html) works.
  Lists returned by
  [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  and friends with `simplify = FALSE` are already `a5_cell_list`
  objects.

Adding rows to a data frame by index (`df[nrow(df) + 1, ] <- ...`) is
not supported for any record-backed column, because base R strips the
class before growing the column. Use
[`rbind()`](https://rdrr.io/r/base/cbind.html) or
[`vctrs::vec_rbind()`](https://vctrs.r-lib.org/reference/vec_bind.html).

``` r

cells <- a5_lonlat_to_cell(c(0, 10, 0), c(0, 10, 0), resolution = 5)

# A leading NA: start with a cell, or use vctrs
c(a5_cell(NA), cells)
vctrs::vec_c(NA, cells)

# Grouping by cell: use vctrs
vctrs::vec_split(1:3, cells)$val
#> [[1]] 1 3   [[2]] 2

# Flattening lapply() output
parts <- lapply(1:3, function(i) a5_cell_to_children(cells[i]))
unlist(as_a5_cell_list(parts))
```

## Summary

| Aspect | Hex strings | Raw bytes |
|----|----|----|
| R type | `character` vector | `vctrs_rcrd` (eight `raw` fields) |
| Memory (1M cells) | ~81 MB | ~7.6 MB |
| R-Rust crossing | O(n) hex parse/format | Zero-copy byte access |
| Human-readable | Always | On [`format()`](https://rdrr.io/r/base/format.html) / [`print()`](https://rdrr.io/r/base/print.html) |
| Lossless | Yes | Yes (one-to-one byte encoding) |
