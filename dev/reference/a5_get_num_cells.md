# Total number of cells at a given resolution

Total number of cells at a given resolution

## Usage

``` r
a5_get_num_cells(resolution)
```

## Arguments

- resolution:

  Integer scalar resolution (0–30).

## Value

A numeric scalar (double) giving the total count. Returned as double
because the count can exceed R's integer range.

## Examples

``` r
a5_get_num_cells(0)
#> [1] 12
a5_get_num_cells(10)
#> [1] 15728640
```
