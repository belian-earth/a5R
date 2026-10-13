# Working with Arrow and Parquet

## The uint64 problem

A5 cell IDs are 64-bit unsigned integers. R has no native `uint64` type,
and its `double` can only represent integers exactly up to 2^53. Nearly
half of all A5 cell IDs exceed this threshold, so converting them to
`double` silently corrupts the data.

This is a problem when reading Parquet files that store A5 cell IDs as
`uint64` columns: the standard format used by DuckDB, Python, and
[geoparquet.io](https://geoparquet.io/). By default,
[`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html)
converts `uint64` to R’s `double`, losing precision:

``` r

library(arrow)
library(tibble)
library(a5R)

# A real A5 cell: Edinburgh at resolution 20
cell <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 20)
a5_u64_to_hex(cell)
#> [1] "63bb93f88f080000"

# Write to Parquet as uint64 (the standard interchange format)
tf <- tempfile(fileext = ".parquet")
arrow::write_parquet(
  arrow::arrow_table(cell_id = a5_cell_to_arrow(cell)),
  tf
)

# Read it back naively: arrow silently converts uint64 to double
(naive <- tibble(arrow::read_parquet(tf)))
#> # A tibble: 1 × 1
#>   cell_id
#>     <dbl>
#> 1 7.19e18

cell_as_dbl <- naive$cell_id

# The double can't distinguish this cell from nearby IDs
cell_as_dbl == cell_as_dbl + 1   # TRUE: silent corruption
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

# Six cities across the globe; some will have bit 63 set (quintant >= 32)
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
#> 1 Edinburgh   -3.19  56.0  63bb948000000000
#> 2 Tokyo      140.    35.7  872fb48000000000
#> 3 São Paulo  -46.6  -23.6  38a5138000000000
#> 4 Nairobi     36.8   -1.29 6fad7b8000000000
#> 5 Anchorage -150.    61.2  012f4c8000000000
#> 6 Sydney     151.   -33.9  9ca4cf8000000000
```

These cells work seamlessly in tibbles. Now let’s enrich the data with
some A5 operations: cell resolution and distance from Edinburgh.

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
#> 1 Edinburgh   -3.19  56.0  63bb948000000000         10                     0 
#> 2 Tokyo      140.    35.7  872fb48000000000         10                  9233.
#> 3 São Paulo  -46.6  -23.6  38a5138000000000         10                  9743.
#> 4 Nairobi     36.8   -1.29 6fad7b8000000000         10                  7317.
#> 5 Anchorage -150.    61.2  012f4c8000000000         10                  6662.
#> 6 Sydney     151.   -33.9  9ca4cf8000000000         10                 16872.
```

## Writing and reading Parquet

Convert to an Arrow table and write to Parquet. The cell column is
stored as native `uint64`, the same binary format used by DuckDB,
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

Read it back.
[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
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
#> 1 Edinburgh 63bb948000000000       10                     0 
#> 2 Tokyo     872fb48000000000       10                  9233.
#> 3 São Paulo 38a5138000000000       10                  9743.
#> 4 Nairobi   6fad7b8000000000       10                  7317.
#> 5 Anchorage 012f4c8000000000       10                  6662.
#> 6 Sydney    9ca4cf8000000000       10                 16872.
```

Verify the round-trip is lossless:

``` r

identical(format(cities$cell), format(result$cell))
#> [1] TRUE
```

## Storing coverings

A covering, such as the cells of a polygon, is stored as a list of
64-bit values: its compacted cells in curve order, then a *compaction
marker* recording the resolution they stand for (see
[`?a5_covering`](https://belian-earth.github.io/a5R/reference/a5_covering.md)).
This is the layout every A5 library uses, so
[`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)
writes coverings to a `list<uint64>` column that DuckDB, Python and
JavaScript read without losing the resolution:

``` r

cities$within_50km <- a5_spherical_cap(cities$cell, radius = 50000)
cities[c("name", "within_50km")]
#> # A tibble: 6 × 2
#>   name      within_50km                  
#>   <chr>     <a5_covering>                
#> 1 Edinburgh res 10: 239 cells (62 stored)
#> 2 Tokyo     res 10: 241 cells (64 stored)
#> 3 São Paulo res 10: 244 cells (73 stored)
#> 4 Nairobi   res 10: 238 cells (58 stored)
#> 5 Anchorage res 10: 241 cells (55 stored)
#> 6 Sydney    res 10: 245 cells (74 stored)

tf <- tempfile(fileext = ".parquet")
arrow::write_parquet(
  arrow::arrow_table(
    name = cities$name,
    cell_id = a5_cell_to_arrow(cities$cell),
    within_50km = a5_covering_to_arrow(cities$within_50km)
  ),
  tf
)
pq <- arrow::read_parquet(tf, as_data_frame = FALSE)
pq$schema
#> Schema
#> name: string
#> cell_id: uint64
#> within_50km: list<element: uint64>
```

[`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)
reads them back. It also accepts coverings written by other A5
libraries, checking, sorting and compacting each one; an element without
a compaction marker stands for the resolution of its finest cell.

``` r

back <- a5_covering_from_arrow(pq$within_50km)
identical(back, cities$within_50km)
#> [1] TRUE
```

Keep the compaction marker when moving coverings through other tools:
the stored cells have mixed resolutions, and without the marker nothing
records which resolution they stand for. Expand a covering with
[`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_compaction.md)
before joining it to data keyed by cell.

## Data written by a5R before 1.0

a5R 1.0 uses A5’s permanent cell-ID system. Its space-filling curve
threads the cells differently from the index used by a5R 0.6 and earlier
(the “v0” index), so every cell has a new id. A v0 id is still a valid
cell in the current index, but in a different place, and nothing in the
id records which version wrote it. Stored v0 ids must be converted
exactly once, as they are read:

``` r

# A resolution-8 cell id written by a5R 0.6
v0 <- a5_cell("59c4780000000000")
a5_migrate(v0)
#> <a5_cell[1]>
#> [1] 59c4280000000000
```

[`a5_migrate()`](https://belian-earth.github.io/a5R/reference/a5_migrate.md)
is a bit operation, so it is cheap on large columns. Apply it to every
stored id column, including the cells inside stored coverings
(`a5_compact(a5_migrate(a5_uncompact(old)))`), or re-index the data from
its coordinates. Upstream will retire the conversion in a future
version.

## How it works under the hood

1.  **[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)**:
    packs the eight raw-byte fields into 8-byte little-endian blobs (one
    per cell), creates an Arrow `fixed_size_binary(8)` array, then uses
    `View(uint64)` to reinterpret the bytes as unsigned 64-bit integers.
    Zero-copy.

2.  **[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)**:
    does the reverse, applying `View(fixed_size_binary(8))` on the
    `uint64` array to get the raw bytes, then unpacks each 8-byte blob
    into the eight raw-byte fields used by `a5_cell`.

3.  **[`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)**
    and
    **[`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)**
    do the same with `list<fixed_size_binary(8)>` and `list<uint64>`:
    each covering is a list element of 8-byte values.

The raw bytes never pass through `double`, so there is no precision loss
at any step. See
[`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/articles/internal-cell-representation.md)
for details on the raw-byte representation.
