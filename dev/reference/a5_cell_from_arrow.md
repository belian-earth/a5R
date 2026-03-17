# Convert between a5_cell and Arrow uint64 arrays

Losslessly convert between
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vectors and Arrow `uint64` arrays. This avoids the precision loss that
occurs when Arrow converts `uint64` to R's `double` (which can only
represent integers exactly up to 2^53, while A5 cell IDs span the full
0–2^64 range).

## Usage

``` r
a5_cell_from_arrow(x)

a5_cell_to_arrow(x)
```

## Arguments

- x:

  For `a5_cell_from_arrow()`, an Arrow `Array` or `ChunkedArray` of type
  `uint64`. For `a5_cell_to_arrow()`, an
  [a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  vector.

## Value

`a5_cell_from_arrow()` returns an
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
vector. `a5_cell_to_arrow()` returns an Arrow `Array` of type `uint64`.

## Details

Internally these use Arrow's zero-copy
[`View()`](https://rdrr.io/r/utils/View.html) to reinterpret `uint64`
bytes as `fixed_size_binary(8)`, then convert to/from the raw-byte
representation used by
[a5_cell](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md).
The resulting Arrow arrays can be written directly to Parquet and read
correctly by DuckDB, Python, and other Arrow-compatible tools.

## See also

[`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
for converting to hex strings instead.

## Examples

``` r
cell <- a5_lonlat_to_cell(135, 0, resolution = 10)
arr <- a5_cell_to_arrow(cell)
back <- a5_cell_from_arrow(arr)
identical(format(cell), format(back))
#> [1] TRUE
cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
arr <- a5_cell_to_arrow(cells)
arr$type$ToString()
#> [1] "uint64"
```
