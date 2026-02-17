# A5 Cell Index Vector

A vctrs-based vector type representing A5 cell indices. Cell IDs are
stored as hex-encoded character strings internally. The `a5_cell` type
provides type safety, pretty-printing, and integration with the vctrs
framework.

## Usage

``` r
a5_cell(x = character())

is_a5_cell(x)

as_a5_cell(x)
```

## Arguments

- x:

  A character vector of hex-encoded A5 cell IDs, or an object coercible
  to one.

## Value

An `a5_cell` vector.

## Examples

``` r
cells <- a5_cell(c("0800000000000006", "0800000000000016"))
cells
#> <a5_cell[2]>
#> [1] 0800000000000006 0800000000000016
```
