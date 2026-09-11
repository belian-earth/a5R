# Changelog

## a5R (development version)

- The benchmark suite now mirrors the TypeScript, Python and Rust A5
  ports (same case names, same deterministic inputs) and runs in CI on
  every pull request, failing on regressions above 15%. The old
  cross-language comparison scripts are gone.

- [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_children.md),
  [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  are vectorised over their cell argument and gain a `simplify`
  argument. The default `simplify = TRUE` returns one flat `a5_cell`
  vector, so single-cell calls are unchanged; `simplify = FALSE` returns
  a [`vctrs::list_of()`](https://vctrs.r-lib.org/reference/list_of.html)
  with one element per input, for list columns. An `NA` cell now
  contributes no cells instead of raising an error.

- New `a5_cell_list` class for those lists, with an
  [`unlist()`](https://rdrr.io/r/base/unlist.html) method that
  concatenates the elements into one `a5_cell` vector. Base
  [`unlist()`](https://rdrr.io/r/base/unlist.html) on a plain list of
  `a5_cell` vectors returns a meaningless raw vector;
  [`as_a5_cell_list()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  wraps such a list so [`unlist()`](https://rdrr.io/r/base/unlist.html)
  works.

- Base R compatibility for `a5_cell` (reported by the ramet project):
  [`match()`](https://rdrr.io/r/base/match.html) and `%in%` are about
  ten times faster via an exact
  [`mtfrm()`](https://rdrr.io/r/base/mtfrm.html) method instead of hex
  conversion; `x[i] <- value` past the end and `length(x) <- n` grow the
  vector with `NA`, so [`rbind()`](https://rdrr.io/r/base/cbind.html) on
  data frames with `a5_cell` columns works.
  [`split()`](https://rdrr.io/r/base/split.html) and
  [`tapply()`](https://rdrr.io/r/base/tapply.html) with an `a5_cell`
  grouping vector cannot be intercepted and give wrong results; use
  [`vctrs::vec_split()`](https://vctrs.r-lib.org/reference/vec_split.html)
  or
  [`vctrs::vec_group_id()`](https://vctrs.r-lib.org/reference/vec_group.html),
  as documented in
  [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/dev/articles/internal-cell-representation.md).

- New
  [`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
  returns the i-th descendant of each cell at a finer resolution without
  enumerating the others, for sampling from large cells.

- New
  [`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
  returns the smallest and largest descendant of each cell at a finer
  resolution. Descendants occupy a contiguous id range among cells of
  that resolution, so the pair is an exact `BETWEEN` filter on an
  id-sorted store. Resolution 30 is refused because the guarantee does
  not hold there.

- Reduced per-call overhead across the package. Rust output is wrapped
  without re-validation, cell fields are passed to Rust without building
  a data frame and read there without R-level `$` calls, scalar
  arguments are checked with a lightweight helper, default `format`,
  `containment` and `method` arguments skip
  [`rlang::arg_match()`](https://rlang.r-lib.org/reference/arg_match.html),
  [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_lonlat_to_cell.md)
  casts and recycles common inputs without vctrs,
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_lonlat.md)
  uses low-level `wk` and data frame constructors, and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_area.md),
  [`a5_cell_edge_length_avg()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_edge_length_avg.md)
  and
  [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  cache the parsed base unit. Scalar calls are three to twenty times
  faster; results, recycling rules and error messages are unchanged.

## a5R 0.6.0

CRAN release: 2026-09-08

- Updated the bundled ‘A5’ Rust crate to 0.10.0. The lattice curve is
  now laid out with an L-system and the equal-area projection is more
  efficient; upstream reports large speed-ups for
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md),
  [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md),
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  and
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_lonlat.md).
  Cell identifiers are unchanged: all existing results and snapshots are
  bit-for-bit identical.
- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  gains a `containment` argument. The default, `"centre"`, keeps the
  existing centre-in-polygon behaviour. The new `"overlapping"` mode
  additionally returns every cell that touches the polygon boundary,
  giving gap-free coverage; the result is a superset of the centre set.
  Hole interiors are still excluded in both modes. This restores the
  boundary-intersection use case previously served by the removed
  `a5_grid()`.
- New
  [`a5_cell_edge_length_avg()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_edge_length_avg.md)
  returns the average edge length of a cell at a given resolution, as a
  `units` vector (metres by default). Individual edges vary from the
  average by roughly +/-10%.
- Fixed the build on Windows ARM64 by bumping `extendr-api` to 0.8.2 and
  passing the correct `--target` on Windows
  ([\#22](https://github.com/belian-earth/a5R/issues/22),
  [@jeroen](https://github.com/jeroen)).

## a5R 0.5.0

CRAN release: 2026-07-02

- Removed `a5_grid()`, deprecated since 0.4.0. Use
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  instead. Note the semantics differ: `a5_grid()` selected every cell a
  geometry touched (boundary intersection), whereas
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  selects cells whose centre lies inside the geometry. For a bounding
  box, pass a closed polygon, e.g.
  `a5_polygon_to_cells(wk::rct(xmin, ymin, xmax, ymax), res)`.
- Dropped the `lifecycle` R dependency and the `wkt` Rust dependency,
  both of which were only needed by `a5_grid()`.
- Replaced the heavy `geo` Rust dependency with the lightweight
  `geographiclib-rs` crate for
  [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md).
  The haversine and rhumb methods are now computed directly; the
  geodesic method continues to use Karney’s algorithm. Distance results
  are unchanged. This removes 33 transitive crates and shrinks the
  vendored sources substantially.
- Updated the bundled ‘A5’ Rust crate to 0.9.0, bringing a faster
  polyhedral projection and an `EqualAreaProjection` refactor.
- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  now delegates hole handling to the upstream crate, which excludes hole
  interiors natively rather than subtracting hole-ring cells in R.
  Results are unchanged; the implementation is simpler and avoids an
  uncompact/recompact round-trip for single-part polygons.

## a5R 0.4.0

CRAN release: 2026-05-14

- `a5_grid()` is soft-deprecated in favour of
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md).
  Calling it now emits a
  [`lifecycle::deprecate_warn()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html)
  with guidance: use
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  for geometry inputs (centre-in-polygon containment), or pass a
  [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html)
  bounding box for the bbox use case. Note that the two functions are
  not semantically identical: `a5_grid()` uses boundary intersection
  (any cell touched by the geometry), whereas
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  uses centre-point containment (cells whose centroid lies inside).
- New
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  returns the A5 cells whose centres lie inside a polygon. Distinct from
  `a5_grid()`, which uses boundary-intersection semantics. Accepts
  wk-handleable geometries (including `MULTIPOLYGON` and `sfc` of
  several polygons), terra `SpatVector` objects, numeric matrices, or
  `data.frame(lon, lat)`. Multi-part inputs are handled natively: per
  polygon part the outer ring’s cells are computed and any hole-ring
  cells are subtracted, then the results are unioned across parts and
  recompacted.
- New
  [`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_linestring_to_cells.md)
  returns the A5 cells whose pentagons are intersected by a great-circle
  polyline, in discovery order along the path. Accepts the same input
  shapes as
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md),
  including `MULTILINESTRING`, `sfc`s of multiple linestrings, and terra
  `SpatVector` objects; per-feature outputs are concatenated with
  first-seen deduplication.
- Bumped the embedded `a5` Rust crate from 0.7.0 to 0.8.0. Transparent
  improvements inherited from upstream: resolution-30 (de)serialisation
  (a5 0.7.1), neighbour functions at resolutions 0 and 1 (a5 0.7.2),
  longitude normalisation in `cell_to_lonlat` (a5 0.7.3), faster
  `cell_to_parent`, and a polar-region spiral fix in `grid_disk` and
  `spherical_cap`.
- **Breaking:**
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_lonlat.md)
  replaces its `normalise` argument with `as_dataframe` (default
  `FALSE`). When `FALSE`, centroids are returned as a
  [`wk::xy()`](https://paleolimbot.github.io/wk/reference/xy.html)
  vector with WGS 84 CRS; when `TRUE`, as a base `data.frame` with
  `lon`/`lat` columns. The previous `normalise` argument toggled
  longitude normalisation, but upstream a5 (\>= 0.7.3) always returns
  normalised longitudes, so the flag’s effective job collapsed to “what
  container?”. `as_dataframe` makes that explicit. Defaults are
  unchanged for users who never set `normalise` (still returns
  [`wk::xy`](https://paleolimbot.github.io/wk/reference/xy.html));
  explicit `normalise = TRUE`/`FALSE` calls now error and must be
  updated.
- New `lifecycle` dependency added to `Imports`.

## a5R 0.3.1

CRAN release: 2026-03-26

- [`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  now requires hex strings to be exactly 16 characters, preventing
  silent construction of wrong cells from truncated input.
- Improved vignettes covering the new `a5_cell` representation and Arrow
  integration.

## a5R 0.3.0

- `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling [`sort()`](https://rdrr.io/r/base/sort.html),
  [`order()`](https://rdrr.io/r/base/order.html),
  [`unique()`](https://rdrr.io/r/base/unique.html),
  [`duplicated()`](https://rdrr.io/r/base/duplicated.html),
  [`match()`](https://rdrr.io/r/base/match.html), and `%in%`
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- `a5_cell` gains an [`is.na()`](https://rdrr.io/r/base/NA.html) method
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- New
  [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  and
  [`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  for lossless conversion between `a5_cell` and Arrow `uint64` arrays,
  enabling zero-copy Parquet I/O
  ([\#12](https://github.com/belian-earth/a5R/issues/12)).
- New
  [`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  and
  [`a5_hex_to_u64()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  for explicit conversion between `a5_cell` vectors and hex strings.
- `a5_is_cell()` has been renamed to
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  and now accepts both `a5_cell` vectors and character hex strings.
- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_area.md)
  gain a `units = NULL` option to return plain numeric vectors without
  `units` class overhead.
- New vignettes:
  [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/dev/articles/internal-cell-representation.md)
  and
  [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/dev/articles/arrow-parquet.md).

## a5R 0.2.0

CRAN release: 2026-03-16

- Initial CRAN submission.
