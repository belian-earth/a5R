# A5 Cell Index Vector

Create, test, and coerce A5 cell index vectors. Cells are stored as a
record with eight raw-byte fields (`b1`–`b8`) representing the
little-endian bytes of the u64 cell ID. This avoids the precision loss
of floating-point storage and keeps memory compact.

## Usage

``` r
a5_cell(x = character())

is_a5_cell(x)

as_a5_cell(x)
```

## Arguments

- x:

  A character vector of hex-encoded A5 cell IDs, or an object coercible
  to one.

## Value

An `a5_cell` vector (`a5_cell`, `as_a5_cell`), or a logical scalar
(`is_a5_cell`).

## Details

Ids are hex strings of up to 16 digits, optionally prefixed with `0x`.
Shorter ids, as some A5 libraries write them, are padded with leading
zeros, and a string that is not a hex id is an error. `a5_cell()` does
not check that an id encodes an A5 cell, so an `a5_cell` vector can hold
values that are not cells. Check ids from outside sources, such as a
file or a database, with
[`a5_is_valid_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md).

## See also

[`a5_is_valid_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
to check that values are A5 cells, and
[`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
for any a5R object;
[`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
to convert back to hex strings;
[`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md)
for ids written by a5R before 1.0.

## Examples

``` r
cells <- a5_cell(c("0800000000000006", "0800000000000016"))
cells
#> <a5_cell[2]>
#> [1] 0800000000000006 0800000000000016
a5_is_valid_cell(cells)
#> [1] TRUE TRUE

# a5_cell() does not validate: this value is not a cell
a5_is_valid_cell(a5_cell("fd00000000000000"))
#> [1] FALSE
```
