# Convert between a5_covering and Arrow `list<uint64>` arrays

Losslessly convert
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vectors to and from Arrow `list<uint64>` arrays, one list element per
covering. Each element holds the covering's compacted cells followed by
its compaction marker, the layout every A5 library uses, so the
resolution travels with the data into Parquet, DuckDB, Python or
JavaScript. A missing covering is a null element.

## Usage

``` r
a5_covering_from_arrow(x)

a5_covering_to_arrow(x)
```

## Arguments

- x:

  For `a5_covering_from_arrow()`, an Arrow `Array` or `ChunkedArray` of
  type `list<uint64>`. For `a5_covering_to_arrow()`, an
  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vector.

## Value

`a5_covering_from_arrow()` returns an
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vector. `a5_covering_to_arrow()` returns an Arrow `Array` of type
`list<uint64>`.

## Details

`a5_covering_from_arrow()` accepts coverings written by any A5 library.
Each one is checked, sorted and compacted; an element without a
compaction marker stands for the resolution of its finest cell.

## See also

[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
for single cells.

## Examples

``` r
cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
disks <- a5_grid_disk(cells, k = 2)
arr <- a5_covering_to_arrow(disks)
arr$type$ToString()
#> [1] "list<item: uint64>"
identical(a5_covering_from_arrow(arr), disks)
#> [1] TRUE
```
