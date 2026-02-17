# Convert hex string to A5 cell

Convenience wrapper to construct an
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md) from
a hex string.

## Usage

``` r
a5_hex_to_cell(hex)
```

## Arguments

- hex:

  Character vector of hex-encoded cell IDs.

## Value

An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
vector.

## Examples

``` r
a5_hex_to_cell("0800000000000006")
#> <a5_cell[1]>
#> [1] 0800000000000006
```
