# Combine coverings

Set operations on
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vectors, computed on the compacted cells without expanding them, so they
stay fast for coverings that stand for billions of cells:

## Usage

``` r
a5_union(x, y = NULL)

a5_intersect(x, y)

a5_difference(x, y)
```

## Arguments

- x, y:

  [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  vectors, or objects
  [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  accepts. Sizes must be compatible under vctrs recycling rules.

## Value

An
[a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
vector of the common size of `x` and `y` (size one for `a5_union(x)`).
`NA` where either input is `NA`; `a5_union(x)` skips `NA` elements.

## Details

- `a5_union()`: cells in either covering. With `y` omitted, the union of
  every covering in `x`, as one covering: for example the coverings of
  all features from
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md).

- `a5_intersect()`: cells in both coverings.

- `a5_difference()`: cells in `x` but not in `y`.

The operations work element by element, recycling a length-one argument,
so `a5_intersect(countries, cap)` intersects every country with one cap.
Both coverings of a pair must be at the same resolution: A5 cells do not
nest geometrically across resolutions, so combining sets at different
resolutions has no meaning, and it is an error. An empty covering with
no recorded resolution, as
[`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
returns for no cells, combines with any covering as the empty set.

## See also

[`a5_contains()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md),
[`a5_overlaps()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
and
[`a5_count()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
to query coverings.

## Examples

``` r
edinburgh <- a5_lonlat_to_cell(-3.19, 55.95, resolution = 12)
glasgow <- a5_lonlat_to_cell(-4.25, 55.86, resolution = 12)
caps <- a5_spherical_cap(c(edinburgh, glasgow), radius = 40000)

a5_union(caps[1], caps[2])
#> <a5_covering[1]>
#> [1] res 12: 4,766 cells (434 stored)
a5_intersect(caps[1], caps[2])
#> <a5_covering[1]>
#> [1] res 12: 195 cells (69 stored)
a5_difference(caps[1], caps[2])
#> <a5_covering[1]>
#> [1] res 12: 2,288 cells (260 stored)

# the union of every element
a5_union(caps)
#> <a5_covering[1]>
#> [1] res 12: 4,766 cells (434 stored)
```
