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
[`a5_get_resolution()`](https://belian-earth.github.io/a5R/reference/a5_get_resolution.md)
or
[`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_parent.md).

## The solution: eight raw-byte fields

A `u64` is exactly 8 bytes. We store each byte of the little-endian
representation as a separate `raw` vector field in a vctrs record type:

    cell_id (u64):  0x0800000000000006

    little-endian bytes:
      b1 = 0x06, b2 = 0x00, b3 = 0x00, b4 = 0x00,
      b5 = 0x00, b6 = 0x00, b7 = 0x00, b8 = 0x08

This is lossless: the eight bytes are the exact same bits as the
original `u64`, just stored across eight contiguous `raw` vectors. No
precision loss, no special-case handling. On the Rust side,
reconstructing the `u64` from the eight byte slices is a single
`u64::from_le_bytes()` call. This also avoids pointers, so there is no
need to think about serialization when saving an `a5_cell` object to
disk.

## R-side: a vctrs record type

On the R side, `a5_cell` is a **vctrs record**
([`vctrs::new_rcrd()`](https://vctrs.r-lib.org/reference/new_rcrd.html))
with eight fields (`b1` through `b8`):

``` r

library(a5R)
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 10)
vctrs::field(cell, "b1")
#> [1] 00
vctrs::field(cell, "b8")
#> [1] 63
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

A5 cell IDs use 60 “quintants” (values 0–59) in their top 6 bits.
Quintant 63 (binary `111111`) is invalid in the A5 system, so we use
`0xFC00000000000000` as a sentinel value for `NA`. In little-endian, the
last byte (`b8`) is `0xFC`, making NA detection a fast single-byte
check.

On the Rust side, the sentinel is detected and mapped to `None`.
Standard R idioms work as expected:

``` r

cells_with_na <- a5_cell(c("0800000000000006", NA))
is.na(cells_with_na)
#> [1] FALSE  TRUE
```

## Summary

| Aspect | Hex strings | Raw bytes |
|----|----|----|
| R type | `character` vector | `vctrs_rcrd` (eight `raw` fields) |
| Memory (1M cells) | ~81 MB | ~7.6 MB |
| R-Rust crossing | O(n) hex parse/format | Zero-copy byte access |
| Human-readable | Always | On [`format()`](https://rdrr.io/r/base/format.html) / [`print()`](https://rdrr.io/r/base/print.html) |
| Lossless | Yes | Yes (exact byte representation) |
