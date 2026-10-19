# Working with Arrow and Parquet

## The uint64 problem

A5 cell ids are 64-bit unsigned integers. R has no native `uint64` type,
and its `double` can only represent integers exactly up to 2^53. Almost
every A5 cell id exceeds this threshold, so converting them to `double`
silently corrupts the data.

This is a problem when reading Parquet files that store A5 cell ids as
`uint64` columns: the standard format used by DuckDB, Python, and
[geoparquet.io](https://geoparquet.io/). By default,
[`arrow::read_parquet()`](https://arrow.apache.org/docs/r/reference/read_parquet.html)
converts `uint64` to R’s `double`, losing precision. The same happens
with
[`dplyr::collect()`](https://dplyr.tidyverse.org/reference/compute.html)
on an Arrow dataset or query.

``` r

library(a5R)
#> a5R 1.0.0 • a5 crate 1.0.0 • A5 index 1.0 • 1 thread
```

``` r

library(arrow)
library(tibble)

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

# The double can't distinguish this cell from nearby ids
cell_as_dbl == cell_as_dbl + 1   # TRUE: silent corruption
#> [1] TRUE
cell_as_dbl == cell_as_dbl + 100 # still TRUE
#> [1] TRUE
```

## The solution: `a5_cell_from_arrow()` and `a5_cell_to_arrow()`

a5R provides two functions that move ids between `a5_cell` and Arrow
`uint64` without passing through `double`:

``` r

# Six cities across the globe. Tokyo and Sydney have bit 63 set: a signed
# int64 would make them negative.
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

Add two ordinary columns to store alongside the cells:

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

[`a5_to_arrow_table()`](https://belian-earth.github.io/a5R/reference/a5_to_arrow_table.md)
converts a data frame to an Arrow table, writing cell columns as native
`uint64`, the binary format DuckDB, Python and geoparquet.io use, and
recording the A5 index version in the schema metadata under the key
`a5_index`, which a5px and a5view write too:

``` r

tf <- tempfile(fileext = ".parquet")
arrow::write_parquet(a5_to_arrow_table(cities), tf)
```

[`a5_from_arrow_table()`](https://belian-earth.github.io/a5R/reference/a5_to_arrow_table.md)
reads it back, recovering the exact ids. It reads every `uint64` column
as cells unless `cells =` names them, and refuses a table tagged with a
different index version:

``` r

pq <- arrow::read_parquet(tf, as_data_frame = FALSE)
pq$schema
#> Schema
#> name: string
#> lon: double
#> lat: double
#> cell: uint64
#> resolution: int32
#> dist_from_edinburgh_km: double
#> 
#> See $metadata for additional Schema metadata
result <- a5_from_arrow_table(pq)
identical(result$cell, cities$cell)
#> [1] TRUE
```

For a single column,
[`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
and
[`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
convert between `a5_cell` and an Arrow `uint64` array.

## Storing coverings

A covering, such as the cells of a polygon, is stored as a list of
64-bit values: its compacted cells in curve order, then a *compaction
marker* recording the resolution they stand for (see
[`vignette("coverings")`](https://belian-earth.github.io/a5R/articles/coverings.md)).
This is the layout every A5 library uses, so covering columns are
written as `list<uint64>`, which DuckDB, Python and JavaScript read
without losing the resolution:

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
arrow::write_parquet(a5_to_arrow_table(cities[c("name", "cell", "within_50km")]), tf)
pq <- arrow::read_parquet(tf, as_data_frame = FALSE)
pq$schema
#> Schema
#> name: string
#> cell: uint64
#> within_50km: list<element: uint64>
#> 
#> See $metadata for additional Schema metadata
```

Reading the table back turns `list<uint64>` columns into coverings.
Coverings written by other A5 libraries are checked, sorted and
compacted; an element without a compaction marker stands for the
resolution of its finest cell.
[`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)
and
[`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_covering_from_arrow.md)
convert a single column.

``` r

back <- a5_from_arrow_table(pq)
identical(back$within_50km, cities$within_50km)
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
id records which version wrote it. Files written before 1.0 carry no
index tag, so
[`a5_from_arrow_table()`](https://belian-earth.github.io/a5R/reference/a5_to_arrow_table.md)
cannot detect them: convert stored v0 ids exactly once, as they are
read.

``` r

# A resolution-8 cell id written by a5R 0.6
v0 <- a5_cell("59c4780000000000")
a5_migrate(v0)
#> <a5_cell[1]>
#> [1] 59c4280000000000
```

[`a5_migrate()`](https://belian-earth.github.io/a5R/reference/a5_migrate.md)
is a bit operation, so it is cheap on large columns. Apply it to every
stored id column, including compacted cell sets, which a5R 0.6 stored as
plain cell columns
(`a5_compact(a5_migrate(a5_uncompact(old, resolution = r)))`), or
re-index the data from its coordinates. Upstream will retire the
conversion in a future version.

## How it works under the hood

All four converters run in Rust and pass one contiguous `uint64` buffer
(a `list<uint64>` for coverings) through the Arrow C data interface,
Arrow’s standard in-memory exchange format. The ids never pass through
`double`, and `NA` cells and missing coverings become nulls. See
[`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/articles/internal-cell-representation.md)
for how `a5_cell` stores ids in R.
