# Convert data frames with cell columns to and from Arrow tables

`a5_to_arrow_table()` converts a data frame to an Arrow `Table`, writing
[a5_cell](https://belian-earth.github.io/a5R/reference/a5_cell.md)
columns as `uint64` and
[a5_covering](https://belian-earth.github.io/a5R/reference/a5_covering.md)
columns as `list<uint64>` (see
[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
and
[`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)),
and records the A5 index version (`a5_info()$index`) in the schema
metadata under `"a5_index"`. `a5_from_arrow_table()` reverses it,
turning `uint64` columns into cells and `list<uint64>` columns into
coverings.

## Usage

``` r
a5_to_arrow_table(x)

a5_from_arrow_table(x, cells = NULL, coverings = NULL)
```

## Arguments

- x:

  For `a5_to_arrow_table()`, a data frame. For `a5_from_arrow_table()`,
  an Arrow `Table`, `RecordBatch`, or anything
  [`arrow::as_arrow_table()`](https://arrow.apache.org/docs/r/reference/as_arrow_table.html)
  accepts, such as a query result.

- cells, coverings:

  Names of the columns to read as cells and as coverings, or `NULL` (the
  default) for every `uint64` and every `list<uint64>` column
  respectively.

## Value

`a5_to_arrow_table()`: an Arrow `Table`. `a5_from_arrow_table()`: a data
frame.

## Details

Ids stay exact throughout, never passing through doubles or text, so the
pair suits Parquet files and DuckDB queries. A table whose metadata
records a different index version is an error, since its ids would name
other cells; convert such ids with
[`a5_migrate()`](https://belian-earth.github.io/a5R/reference/a5_migrate.md).

## See also

[`a5_info()`](https://belian-earth.github.io/a5R/reference/a5_info.md)

## Examples

``` r
cells <- a5_lonlat_to_cell(c(-3.19, 135), c(55.95, 0), resolution = 10)
df <- data.frame(cell = cells, value = c(1.5, 2.5))
df$disk <- a5_grid_disk(cells, k = 1)
tbl <- a5_to_arrow_table(df)
tbl$schema
#> Schema
#> cell: uint64
#> value: double
#> disk: list<item: uint64>
#> 
#> See $metadata for additional Schema metadata
back <- a5_from_arrow_table(tbl)
identical(back$cell, df$cell)
#> [1] TRUE
```
