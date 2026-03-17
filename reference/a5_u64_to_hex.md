# Coerce between hex strings and A5 cell vectors

`a5_u64_to_hex()` converts an
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector to 16-character zero-padded hex strings. `a5_hex_to_u64()`
converts hex strings to an
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector.

## Usage

``` r
a5_u64_to_hex(x)

a5_hex_to_u64(x)
```

## Arguments

- x:

  For `a5_u64_to_hex()`, an
  [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector (or object coercible to one). For `a5_hex_to_u64()`, a
  character vector of hex-encoded cell IDs.

## Value

`a5_u64_to_hex()` returns a character vector. `a5_hex_to_u64()` returns
an [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector.

## Details

These are named to match `u64_to_hex` / `hex_to_u64` in the upstream
Python, JavaScript, and DuckDB A5 bindings. In those languages the
functions convert between a native 64-bit unsigned integer and its hex
representation. Because R has no native `uint64` type, `a5_u64_to_hex()`
accepts an
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
(which stores the `u64` internally as eight raw bytes) instead of a bare
integer.

## See also

[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
and
[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
for lossless conversion between
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md) and
Arrow `uint64` arrays.

## Examples

``` r
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 5)
hex <- a5_u64_to_hex(cell)
hex
#> [1] "633e000000000000"

a5_hex_to_u64(hex)
#> <a5_cell[1]>
#> [1] 633e000000000000
```
