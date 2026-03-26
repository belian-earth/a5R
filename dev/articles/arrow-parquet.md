# Working with Arrow and Parquet

## The uint64 problem

A5 cell IDs are 64-bit unsigned integers. R has no native `uint64` type,
and its `double` can only represent integers exactly up to 2^53. Nearly
half of all A5 cell IDs exceed this threshold, so converting them to
`double` silently corrupts the data.

This is a problem when reading Parquet files that store A5 cell IDs as
`uint64` columns — the standard format used by DuckDB, Python, and
[geoparquet.io](https://geoparquet.io/). By default,
[`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html)
converts `uint64` to R’s `double`, losing precision:

``` r
library(arrow)
library(tibble)
library(a5R)

# A real A5 cell — Edinburgh at resolution 20
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 20)
a5_u64_to_hex(cell)
#> [1] "6344bba17af80000"

# Write to Parquet as uint64 (the standard interchange format)
tf <- tempfile(fileext = ".parquet")
arrow::write_parquet(
  arrow::arrow_table(cell_id = a5_cell_to_arrow(cell)),
  tf
)

# Read it back naively — arrow silently converts uint64 to double
(naive <- tibble(arrow::read_parquet(tf)))
#> # A tibble: 1 × 1
#>   cell_id
#>     <dbl>
#> 1 7.15e18

cell_as_dbl <- naive$cell_id

# The double can't distinguish this cell from nearby IDs
cell_as_dbl == cell_as_dbl + 1   # TRUE — silent corruption
#> [1] TRUE
cell_as_dbl == cell_as_dbl + 100 # still TRUE
#> [1] TRUE
```

## The solution: `a5_cell_from_arrow()` and `a5_cell_to_arrow()`

a5R provides two functions that bypass the lossy `double` conversion
entirely, using Arrow’s zero-copy
[`View()`](https://rdrr.io/r/utils/View.html) to reinterpret the raw
bytes:

``` r
library(a5R)
library(tibble)

# Six cities across the globe — some will have bit 63 set (origin >= 6)
cities <- tibble(
  name = c("Edinburgh", "Tokyo", "São Paulo", "Nairobi", "Anchorage", "Sydney"),
  lon  = c(   -3.19,     139.69,     -46.63,     36.82,    -149.90,    151.21),
  lat  = c(   55.95,      35.69,     -23.55,     -1.29,      61.22,    -33.87)
)

cities$cell <- a5_lonlat_to_cell(cities$lon, cities$lat, resolution = 10)
cities
#> # A tibble: 6 × 4
#>   name          lon    lat cell            
#>   <chr>       <dbl>  <dbl> <a5_cell>       
#> 1 Edinburgh   -3.19  56.0  6344be8000000000
#> 2 Tokyo      140.    35.7  872f8a8000000000
#> 3 São Paulo  -46.6  -23.6  377f908000000000
#> 4 Nairobi     36.8   -1.29 6fad538000000000
#> 5 Anchorage -150.    61.2  00d1c38000000000
#> 6 Sydney     151.   -33.9  8f7ec58000000000
```

These cells work seamlessly in tibbles. Now let’s enrich the data with
some A5 operations — cell resolution and distance from Edinburgh:

``` r
edinburgh <- cities$cell[1]

cities$resolution <- a5_get_resolution(cities$cell)
cities$dist_from_edinburgh_km <- as.numeric(
  a5_cell_distance(cities$cell, rep(edinburgh, nrow(cities)), units = "km")
)

cities
#> # A tibble: 6 × 6
#>   name          lon    lat cell             resolution dist_from_edinburgh_km
#>   <chr>       <dbl>  <dbl> <a5_cell>             <int>                  <dbl>
#> 1 Edinburgh   -3.19  56.0  6344be8000000000         10                     0 
#> 2 Tokyo      140.    35.7  872f8a8000000000         10                  9233.
#> 3 São Paulo  -46.6  -23.6  377f908000000000         10                  9743.
#> 4 Nairobi     36.8   -1.29 6fad538000000000         10                  7317.
#> 5 Anchorage -150.    61.2  00d1c38000000000         10                  6662.
#> 6 Sydney     151.   -33.9  8f7ec58000000000         10                 16872.
```

## Writing and reading Parquet

Convert to an Arrow table and write to Parquet. The cell column is
stored as native `uint64` — the same binary format used by DuckDB,
Python, and geoparquet.io:

``` r
tf <- tempfile(fileext = ".parquet")

arrow_tbl <- arrow::arrow_table(
  name = cities$name,
  cell_id = a5_cell_to_arrow(cities$cell),
  cell_res = cities$resolution,
  dist_from_edinburgh_km = cities$dist_from_edinburgh_km
)
arrow_tbl$schema
#> Schema
#> name: string
#> cell_id: uint64
#> cell_res: int32
#> dist_from_edinburgh_km: double
arrow::write_parquet(arrow_tbl, tf)
```

Read it back —
[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
recovers the exact cell IDs without any precision loss:

``` r
pq <- arrow::read_parquet(tf, as_data_frame = FALSE)

# Recover cells from the uint64 column, bind with the rest of the data
recovered_cells <- a5_cell_from_arrow(pq$column(1))
result <- as.data.frame(pq)
result$cell <- recovered_cells
result <- tibble::as_tibble(result[c("name", "cell", "cell_res", "dist_from_edinburgh_km")])
result
#> # A tibble: 6 × 4
#>   name      cell             cell_res dist_from_edinburgh_km
#>   <chr>     <a5_cell>           <int>                  <dbl>
#> 1 Edinburgh 6344be8000000000       10                     0 
#> 2 Tokyo     872f8a8000000000       10                  9233.
#> 3 São Paulo 377f908000000000       10                  9743.
#> 4 Nairobi   6fad538000000000       10                  7317.
#> 5 Anchorage 00d1c38000000000       10                  6662.
#> 6 Sydney    8f7ec58000000000       10                 16872.
```

Verify the round-trip is lossless:

``` r
identical(format(cities$cell), format(result$cell))
#> [1] TRUE
```

## How it works under the hood

1.  **[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)**:
    packs the eight raw-byte fields into 8-byte little-endian blobs (one
    per cell), creates an Arrow `fixed_size_binary(8)` array, then uses
    `View(uint64)` to reinterpret the bytes as unsigned 64-bit integers
    — zero-copy.

2.  **[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)**:
    does the reverse — `View(fixed_size_binary(8))` on the `uint64`
    array to get the raw bytes, then unpacks each 8-byte blob into the
    eight raw-byte fields used by `a5_cell`.

The raw bytes never pass through `double`, so there is no precision loss
at any step. See
[`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/dev/articles/internal-cell-representation.md)
for details on the raw-byte representation.
