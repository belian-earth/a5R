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
#> 
#> Attaching package: 'arrow'
#> The following object is masked from 'package:utils':
#> 
#>     timestamp

# Simulate: two uint64 values, one below and one above 2^53
below <- 576460752303423494   # fits exactly in double
above <- 576460752303423494 + 576460752303423494  # exceeds 2^53

cat("2^53:    ", format(2^53, scientific = FALSE), "\n")
#> 2^53:     9007199254740992
cat("'above': ", format(above, scientific = FALSE), "\n")
#> 'above':  1152921504606846976
cat("Same as 'above + 1'?", above == above + 1, "\n")
#> Same as 'above + 1'? TRUE
# TRUE — precision has already been lost
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
some A5 operations — cell area, resolution, and distance from Edinburgh:

``` r
edinburgh <- cities$cell[1]

cities$area_km2 <- as.numeric(a5_cell_area(10)) / 1e6
cities$resolution <- a5_get_resolution(cities$cell)
cities$dist_from_edinburgh_km <- as.numeric(
  a5_cell_distance(cities$cell, rep(edinburgh, nrow(cities)))
) / 1000

cities
#> # A tibble: 6 × 7
#>   name          lon    lat cell             area_km2 resolution
#>   <chr>       <dbl>  <dbl> <a5_cell>           <dbl>      <int>
#> 1 Edinburgh   -3.19  56.0  6344be8000000000     32.4         10
#> 2 Tokyo      140.    35.7  872f8a8000000000     32.4         10
#> 3 São Paulo  -46.6  -23.6  377f908000000000     32.4         10
#> 4 Nairobi     36.8   -1.29 6fad538000000000     32.4         10
#> 5 Anchorage -150.    61.2  00d1c38000000000     32.4         10
#> 6 Sydney     151.   -33.9  8f7ec58000000000     32.4         10
#> # ℹ 1 more variable: dist_from_edinburgh_km <dbl>
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
  area_km2 = cities$area_km2,
  dist_from_edinburgh_km = cities$dist_from_edinburgh_km
)
arrow_tbl$schema
#> Schema
#> name: string
#> cell_id: uint64
#> area_km2: double
#> dist_from_edinburgh_km: double
arrow::write_parquet(arrow_tbl, tf)
```

Read it back —
[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
recovers the exact cell IDs without any precision loss:

``` r
pq <- arrow::read_parquet(tf, as_data_frame = FALSE)

# Recover cells from the uint64 column, bind with the rest of the data
recovered_cells <- a5_cell_from_arrow(pq$column(1))
result <- as.data.frame(pq)
result$cell <- recovered_cells
result <- tibble::as_tibble(result[c("name", "cell", "area_km2", "dist_from_edinburgh_km")])
result
#> # A tibble: 6 × 4
#>   name      cell             area_km2 dist_from_edinburgh_km
#>   <chr>     <a5_cell>           <dbl>                  <dbl>
#> 1 Edinburgh 6344be8000000000     32.4                     0 
#> 2 Tokyo     872f8a8000000000     32.4                  9233.
#> 3 São Paulo 377f908000000000     32.4                  9743.
#> 4 Nairobi   6fad538000000000     32.4                  7317.
#> 5 Anchorage 00d1c38000000000     32.4                  6662.
#> 6 Sydney    8f7ec58000000000     32.4                 16872.
```

Verify the round-trip is lossless:

``` r
identical(format(cities$cell), format(result$cell))
#> [1] TRUE
```

## How it works under the hood

1.  **[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)**:
    packs the eight raw-byte fields into 8-byte little-endian blobs (one
    per cell), creates an Arrow `fixed_size_binary(8)` array, then uses
    `View(uint64)` to reinterpret the bytes as unsigned 64-bit integers
    — zero-copy.

2.  **[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)**:
    does the reverse — `View(fixed_size_binary(8))` on the `uint64`
    array to get the raw bytes, then unpacks each 8-byte blob into the
    eight raw-byte fields used by `a5_cell`.

The raw bytes never pass through `double`, so there is no precision loss
at any step. See
[`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/articles/internal-cell-representation.md)
for details on the raw-byte representation.
