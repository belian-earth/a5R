# a5R build and session information

Returns the versions behind a5R and its current settings, as a named
list that prints as a summary. The same summary, on one line, is shown
when the package is attached with
[`library()`](https://rdrr.io/r/base/library.html).

## Usage

``` r
a5_info()
```

## Value

A list of class `a5_info` with elements:

- `version`: the a5R package version, a character scalar.

- `crate`: the version of the bundled a5 Rust crate.

- `index`: the A5 cell index version of a5R's ids, `"1.0"`.

- `threads`: the current thread count (see
  [`a5_set_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)).

- `c_api`: the version of the C API (see
  [a5_c_api](https://belian-earth.github.io/a5R/dev/reference/a5_c_api.md)).

## Details

The `index` element names the A5 cell index that a5R's ids belong to.
Ids from different index versions look alike, and nothing in an id says
which version wrote it (see
[`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md)),
so record `index` with stored cells and check it when reading them back.
With Arrow and Parquet,
[`a5_to_arrow_table()`](https://belian-earth.github.io/a5R/dev/reference/a5_to_arrow_table.md)
stores it in the schema metadata under the key `"a5:index_version"`, and
[`a5_from_arrow_table()`](https://belian-earth.github.io/a5R/dev/reference/a5_to_arrow_table.md)
checks it.

## Examples

``` r
a5_info()
#> ── a5R 0.9.9.9005 ──────────────────────────────────────────────────────────────
#> a5 crate: 1.0.0
#> A5 index: 1.0
#> Threads: 1
#> C API: 1
a5_info()$index
#> [1] "1.0"
```
