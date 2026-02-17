# Test if values are valid A5 cell indices

Checks whether each element is a syntactically valid hex-encoded A5 cell
ID.

## Usage

``` r
a5_is_cell(x)
```

## Arguments

- x:

  An [a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  vector or character vector of hex strings.

## Value

A logical vector.

## Examples

``` r
a5_is_cell(c("0800000000000006", "not_a_cell", NA))
#> [1]  TRUE FALSE    NA
```
