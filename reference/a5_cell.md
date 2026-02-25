# A5 Cell Index Vector

Create, test, and coerce A5 cell index vectors. Cells are stored as
hex-encoded character strings.

## Usage

``` r
a5_cell(x = character())

is_a5_cell(x)

as_a5_cell(x)

a5_is_cell(x)
```

## Arguments

- x:

  A character vector of hex-encoded A5 cell IDs, or an object coercible
  to one.

## Value

An `a5_cell` vector (`a5_cell`, `as_a5_cell`), a logical scalar
(`is_a5_cell`), or a logical vector (`a5_is_cell`).

## Examples

``` r
cells <- a5_cell(c("0800000000000006", "0800000000000016"))
cells
#> <a5_cell[2]>
#> [1] 0800000000000006 0800000000000016
a5_is_cell(c("0800000000000006", "not_a_cell", NA))
#> [1]  TRUE FALSE    NA
```
