# a5R (development version)

## Breaking changes

* a5R now uses the a5 Rust crate 1.0.0-beta.3, which introduces A5's
  permanent cell-ID system. The space-filling curve and the order of the
  dodecahedron faces are new, so **every cell id changes**: an id written by
  an earlier version of a5R is still a valid cell, but in a different place,
  and nothing in the id says which version wrote it. Re-index stored data
  from its coordinates, or convert the ids once with the new `a5_migrate()`.
* Resolution-1 cells are now pentagons rather than triangles, so their
  boundaries and centres change. Cells at every other resolution keep their
  shape and position.
* Compacted cell sets are now `a5_covering` vectors, one covering per
  element. A covering stores its compacted cells followed by a compaction
  marker recording the resolution they stand for, as in the other A5
  libraries, so `a5_uncompact()` no longer needs a resolution. Coverings
  print as their resolution, cell count and stored-cell count, work as data
  frame columns, and compare equal with `==` when they hold the same cells.
  Use `a5_uncompact()` for the cells; `as_a5_cell()` refuses a covering
  rather than treat its stored cells, whose outlines do not nest, as a grid.
* `a5_compact()`, `a5_grid_disk()` and `a5_spherical_cap()` return
  coverings. `a5_grid_disk()` and `a5_spherical_cap()` give one covering
  per centre cell and lose their `simplify` argument, which moves to
  `a5_uncompact()`. An `NA` centre gives an `NA` covering.
* `a5_polygon_to_cells()` returns one covering per feature instead of the
  union of all features, so it can fill a column of an `sf` data frame.
  A feature's parts and holes are still combined. A missing geometry gives
  an `NA` covering and an empty geometry an empty covering; both used to be
  errors.
* `a5_linestring_to_cells()` gains `simplify`: with `simplify = FALSE` it
  returns an `a5_cell_list` with one ordered path per feature, for a list
  column. The default flat form concatenates the paths, so a cell crossed
  by several features now appears once per feature rather than once
  overall; within a feature, each cell still appears once. Missing and
  empty geometries contribute no cells instead of an error.
* `a5_uncompact()` takes coverings, and its `resolution` argument is
  optional: by default each covering expands to its own resolution. It
  refuses to build more than `.Machine$integer.max` cells.
* `a5_is_valid()` now checks the index encoding. It used to return `TRUE`
  for any non-missing `a5_cell` and for any hex string that parsed, whether
  or not the value was a cell; hex strings must now also be 16 digits.
* `a5_compact()`'s first argument is now `cell`, as in other functions that
  take cells, rather than `cells`.

## New features

* `a5_polygon_to_cells()` accepts `containment = "center"` as well as
  `"centre"`, and `a5_spherical_cap()` gains `units`, taking the radius in
  any length unit or as a `units` object.
* Errors have class `a5R_error` and a subclass naming what went wrong, such
  as `a5R_error_resolution` or `a5R_error_geometry`, so code can handle them
  without matching messages. See `?a5_errors`.
* New `a5_index_version()` names the A5 index of a5R's ids ("1.0"), to
  record with stored cells, and `a5_crate_version()` gives the version of
  the bundled a5 Rust crate.
* a5R exports a C API (`a5R.h`, see `?a5_c_api`) for packages that convert
  between 64-bit ids and `a5_cell` vectors in compiled code, so they need
  not rely on how `a5_cell` stores its data.
* New `a5_bbox()` gives the longitude/latitude box of polygons as A5 sees
  them, with great-circle edges that can bow beyond the vertices' latitudes.
* New `a5_covering_to_supercells()` gives the coarse cells containing the
  centres of a covering's cells without building them.
* `with(a5_set_threads(n), expr)` runs `expr` on `n` threads and restores
  the previous count afterwards, as `with(mirai::daemons(n), expr)` does.
  `a5_set_threads()` returns the previous count as an `a5_threads` object to
  make this work.
* New `a5_to_arrow_table()` and `a5_from_arrow_table()` convert data frames
  with cell and covering columns to and from Arrow tables, tagging the
  table with the index version and refusing tables from another index.
* New `a5_migrate()` converts ids from a5R before 1.0 to the current index.
* New `as_a5_covering()` builds coverings from cells, cell lists or raw
  64-bit values written by other A5 libraries, sorting and compacting them;
  `a5_covering_resolution()` returns the resolution each covering stands
  for. `a5_is_valid()` checks covering structure.
* New covering operations, computed on the compacted cells without
  expanding them: `a5_union()`, `a5_intersect()` and `a5_difference()`
  combine coverings element by element, and `a5_union(x)` merges every
  covering in `x`; `a5_contains()` tests cells against coverings (a
  point-in-polygon test at the covering's resolution) and `a5_overlaps()`
  tests pairs of coverings; `a5_count()` and `a5_area()` give the number of
  cells and the area each covering stands for. Combining coverings at
  different resolutions is an error, as upstream.
* New `a5_covering_stored()` returns the compacted cells a covering
  stores, without the compaction marker, for index range queries with
  `a5_cell_children_range()`.
* New `a5_covering_to_arrow()` and `a5_covering_from_arrow()` convert
  coverings to and from Arrow `list<uint64>` with the compaction marker, the
  layout DuckDB, Python and JavaScript A5 code read.
* New `a5_is_valid_cell()` checks that values are A5 cells, mirroring the
  upstream `is_valid_cell`. `a5_is_valid()` becomes a generic that also
  accepts an `a5_cell_list`, returning one value per element.
* New `a5_cell_to_boundary_xy()` returns the boundary vertices of many
  cells as flat `x` and `y` vectors with per-cell `lengths`, ready for a
  single `grid::polygonGrob()`. It skips building a geometry per cell, so
  it is about 1.5 times faster than `a5_cell_to_boundary()` followed by
  `wk::wk_coords()` on one thread, 3 times faster on four, and allocates an
  eighth of the memory.

## Other changes

* Functions returning many cells write them straight into R's vectors, in
  parallel when threads are enabled, instead of staging them first:
  `a5_uncompact()` is about 2.5 times faster on millions of cells, and
  `a5_cell_to_lonlat()` and `a5_cell_to_parent()` up to a third faster,
  with lower peak memory.
* `a5_lonlat_to_cell()` returns `NA` for `NaN` and infinite coordinates,
  which used to give valid cells, and errors on latitudes outside
  \[-90, 90\], which used to wrap onto plausible but wrong cells.
* A panic inside the a5 crate during a multi-threaded call no longer leaves
  every later parallel call, and `a5_set_threads()`, failing until R
  restarts. `a5_set_threads()` rejects counts below 1 and `NA`, and keeps
  the previous count if the thread pool cannot be built.
* `a5_cell()` accepts ids of fewer than 16 hex digits, as written by a5-js
  and DuckDB, and a `0x` prefix. A string that is not a hex id is now an
  error instead of a silent `NA`.
* `NA` cells are missing to vctrs: `==` against `NA` gives `NA`, and
  sorting puts `NA` last instead of among the resolution-30 cells.
* `as_a5_covering()` treats `NULL` list elements as missing coverings, so
  null coverings read back from Arrow stay `NA` instead of becoming empty.
* `a5_polygon_to_cells()` and `a5_linestring_to_cells()` error on `sf` and
  `terra` input in a projected CRS, and on coordinates outside the
  longitude/latitude range. The documentation now warns that
  self-intersecting rings give undefined results.
* `a5_grid_disk()` rejects a negative or `NA` `k`, and
  `a5_spherical_cap()` a negative or non-finite `radius`.
* `a5_uncompact()`'s size guard counts the 5 children of a resolution-0
  cell, so it no longer lets through requests up to 25% over the limit.
* Scalar resolution arguments reject `NA` with a clear error, and
  `a5_get_num_children()` errors when the child resolution is coarser than
  the parent instead of returning 0.
* `a5_cell_from_arrow()` and `a5_covering_from_arrow()` give a clear error
  for input that is not an Arrow array.
* `a5_cell_children_range()` and `a5_cell_child()` reach resolution 29 from
  any cell, as documented, instead of erroring beyond 20 levels.
* The world cell's boundary is `POLYGON EMPTY` instead of an invalid
  polygon.
* `a5_cell_to_parent()` errors when `resolution` is finer than a cell's
  resolution, instead of returning a descendant.
* `a5_cell_to_boundary()` builds its output faster, with identical
  results: on a million cells, WKB takes about 25% less time on one thread
  and half the time on four, and WKT about 20% less.
* `a5_cell_to_boundary()` rejects a `segments` value below 1 or `NA`;
  a negative value used to hang. Its documentation now gives the default,
  `max(1, 2^(6 - resolution))` segments per edge, and how far a single
  segment strays from the curved cell edge at each resolution.
* `a5_polygon_to_cells()` handles `wk::rct()` boxes that previously gave
  wrong results. A box covering the whole globe gives every cell instead of
  none, and a box reaching from pole to pole keeps its west and east edges
  on their meridians. Any other box spanning 180 degrees of longitude or
  more is an error, because its great-circle edges would run the short way
  round. The documentation now states that polygon edges are great circles.
* New `vignette("coverings")` on building, combining, testing and measuring
  coverings. `vignette("arrow-parquet")` covers storing coverings and
  migrating data written before 1.0, and `vignette("spatial-hierarchy")` is
  rewritten for supercells and subcells.

* `a5_cell_to_arrow()`, `a5_cell_from_arrow()`, `a5_covering_to_arrow()` and
  `a5_covering_from_arrow()` run in Rust and pass one contiguous `uint64`
  buffer through the Arrow C data interface, instead of building an R object
  per cell. On 10 million cells, writing to Arrow is about 90 times faster
  and reading about 40 times faster. `a5_covering_from_arrow()` now refuses
  a covering that holds a null cell; it used to drop the null silently.

* `a5_cell_child()` and `a5_cell_children_range()` follow the new order of
  `a5_cell_to_children()` (children are now in ascending id order).
* `a5_get_num_cells()` is correct at high resolutions (a5 0.10.1).
* `a5_polygon_to_cells()` merges a feature's parts with the upstream
  covering union, without expanding each part to full resolution first.

* New `a5_cell_to_supercell()` and `a5_cell_to_subcell()` move between
  resolutions by cell centre rather than by index, wrapping the upstream
  `cell_to_supercell()` and `cell_to_subcell()`. The A5 index hierarchy is
  not spatially nested: for about half of cells one resolution apart, and
  about 35% at four or more apart, the index parent is not the coarse cell
  containing the fine cell's centre. Supercells and subcells form an exact
  partition, so aggregating fine cells to a coarser grid counts each fine
  cell once, inside the coarse cell it lies in. Subcells are returned as one
  covering per cell. `a5_cell_to_parent()` and `a5_cell_to_children()` are
  unchanged and now document the difference (requested by
  belian-production).

* Missing values filled in by vctrs are now `NA`, not the world cell (#27).
  Combining with `NA`, subsetting with an `NA` index, assigning `NA`,
  `vctrs::vec_init()`, and unmatched rows from `merge(all = TRUE)`,
  `vctrs::vec_rbind()` or dplyr joins used to produce id 0, a valid cell. The
  top byte of each id is now stored XOR `0xFC`, so a filled-in gap decodes to
  the NA sentinel, at no measurable cost. This changes the stored byte layout:
  `a5_cell` objects saved with `saveRDS()`, `save()` or qs by earlier versions
  do not read correctly. Re-create them from hex strings or Arrow, which store
  the true id.
* Resolution-30 cells whose id starts with `0xFC` (about 0.3% of them, in
  quintants 31, 39 and 41) are no longer treated as `NA`. The NA check now
  compares the full id rather than its top byte.

* The benchmark suite now mirrors the TypeScript, Python and Rust A5 ports
  (same case names, same deterministic inputs) and runs in CI on every pull
  request, failing on regressions above 15%. The old cross-language
  comparison scripts are gone.

* `a5_cell_to_children()`, `a5_grid_disk()` and `a5_spherical_cap()` are
  vectorised over their cell argument and gain a `simplify` argument. The
  default `simplify = TRUE` returns one flat `a5_cell` vector, so single-cell
  calls are unchanged; `simplify = FALSE` returns a `vctrs::list_of()` with
  one element per input, for list columns. An `NA` cell now contributes no
  cells instead of raising an error.
* New `a5_cell_list` class for those lists, with an `unlist()` method that
  concatenates the elements into one `a5_cell` vector. Base `unlist()` on a
  plain list of `a5_cell` vectors returns a meaningless raw vector;
  `as_a5_cell_list()` wraps such a list so `unlist()` works.
* Base R compatibility for `a5_cell` (reported by the ramet project):
  `match()` and `%in%` are about ten times faster via an exact `mtfrm()`
  method instead of hex conversion; `x[i] <- value` past the end and
  `length(x) <- n` grow the vector with `NA`, so `rbind()` on data frames
  with `a5_cell` columns works. `split()` and `tapply()` with an `a5_cell`
  grouping vector cannot be intercepted and give wrong results; use
  `vctrs::vec_split()` or `vctrs::vec_group_id()`, as documented in
  `vignette("internal-cell-representation")`.

* New `a5_cell_child()` returns the i-th descendant of each cell at a finer
  resolution without enumerating the others, for sampling from large cells.
* New `a5_cell_children_range()` returns the smallest and largest descendant
  of each cell at a finer resolution. Descendants occupy a contiguous id range
  among cells of that resolution, so the pair is an exact `BETWEEN` filter on
  an id-sorted store. Resolution 30 is refused because the guarantee does not
  hold there.

* Reduced per-call overhead across the package. Rust output is wrapped
  without re-validation, cell fields are passed to Rust without building a
  data frame and read there without R-level `$` calls, scalar arguments are
  checked with a lightweight helper, default `format`, `containment` and
  `method` arguments skip `rlang::arg_match()`, `a5_lonlat_to_cell()` casts
  and recycles common inputs without vctrs, `a5_cell_to_lonlat()` uses
  low-level `wk` and data frame constructors, and `a5_cell_area()`,
  `a5_cell_edge_length_avg()` and `a5_cell_distance()` cache the parsed base
  unit. Scalar calls are three to twenty times faster; results, recycling
  rules and error messages are unchanged.

# a5R 0.6.0

* Updated the bundled 'A5' Rust crate to 0.10.0. The lattice curve is now
  laid out with an L-system and the equal-area projection is more
  efficient; upstream reports large speed-ups for `a5_polygon_to_cells()`,
  `a5_grid_disk()`, `a5_spherical_cap()` and `a5_cell_to_lonlat()`. Cell
  identifiers are unchanged: all existing results and snapshots are
  bit-for-bit identical.
* `a5_polygon_to_cells()` gains a `containment` argument. The default,
  `"centre"`, keeps the existing centre-in-polygon behaviour. The new
  `"overlapping"` mode additionally returns every cell that touches the
  polygon boundary, giving gap-free coverage; the result is a superset of
  the centre set. Hole interiors are still excluded in both modes. This
  restores the boundary-intersection use case previously served by the
  removed `a5_grid()`.
* New `a5_cell_edge_length_avg()` returns the average edge length of a cell
  at a given resolution, as a `units` vector (metres by default). Individual
  edges vary from the average by roughly +/-10%.
* Fixed the build on Windows ARM64 by bumping `extendr-api` to 0.8.2 and
  passing the correct `--target` on Windows (#22, @jeroen).

# a5R 0.5.0

* Removed `a5_grid()`, deprecated since 0.4.0. Use `a5_polygon_to_cells()`
  instead. Note the semantics differ: `a5_grid()` selected every cell a
  geometry touched (boundary intersection), whereas `a5_polygon_to_cells()`
  selects cells whose centre lies inside the geometry. For a bounding box,
  pass a closed polygon, e.g.
  `a5_polygon_to_cells(wk::rct(xmin, ymin, xmax, ymax), res)`.
* Dropped the `lifecycle` R dependency and the `wkt` Rust dependency, both
  of which were only needed by `a5_grid()`.
* Replaced the heavy `geo` Rust dependency with the lightweight
  `geographiclib-rs` crate for `a5_cell_distance()`. The haversine and
  rhumb methods are now computed directly; the geodesic method continues to
  use Karney's algorithm. Distance results are unchanged. This removes 33
  transitive crates and shrinks the vendored sources substantially.
* Updated the bundled 'A5' Rust crate to 0.9.0, bringing a faster
  polyhedral projection and an `EqualAreaProjection` refactor.
* `a5_polygon_to_cells()` now delegates hole handling to the upstream
  crate, which excludes hole interiors natively rather than subtracting
  hole-ring cells in R. Results are unchanged; the implementation is
  simpler and avoids an uncompact/recompact round-trip for single-part
  polygons.

# a5R 0.4.0

* `a5_grid()` is soft-deprecated in favour of `a5_polygon_to_cells()`.
  Calling it now emits a `lifecycle::deprecate_warn()` with guidance: use
  `a5_polygon_to_cells()` for geometry inputs (centre-in-polygon
  containment), or pass a `wk::rct()` bounding box for the bbox use
  case. Note that the two functions are not semantically identical:
  `a5_grid()` uses boundary intersection (any cell touched by the
  geometry), whereas `a5_polygon_to_cells()` uses centre-point
  containment (cells whose centroid lies inside).
* New `a5_polygon_to_cells()` returns the A5 cells whose centres lie
  inside a polygon. Distinct from `a5_grid()`, which uses
  boundary-intersection semantics. Accepts wk-handleable geometries
  (including `MULTIPOLYGON` and `sfc` of several polygons), terra
  `SpatVector` objects, numeric matrices, or `data.frame(lon, lat)`.
  Multi-part inputs are handled natively: per polygon part the outer
  ring's cells are computed and any hole-ring cells are subtracted,
  then the results are unioned across parts and recompacted.
* New `a5_linestring_to_cells()` returns the A5 cells whose pentagons
  are intersected by a great-circle polyline, in discovery order along
  the path. Accepts the same input shapes as `a5_polygon_to_cells()`,
  including `MULTILINESTRING`, `sfc`s of multiple linestrings, and
  terra `SpatVector` objects; per-feature outputs are concatenated
  with first-seen deduplication.
* Bumped the embedded `a5` Rust crate from 0.7.0 to 0.8.0. Transparent
  improvements inherited from upstream: resolution-30 (de)serialisation
  (a5 0.7.1), neighbour functions at resolutions 0 and 1 (a5 0.7.2),
  longitude normalisation in `cell_to_lonlat` (a5 0.7.3), faster
  `cell_to_parent`, and a polar-region spiral fix in `grid_disk` and
  `spherical_cap`.
* **Breaking:** `a5_cell_to_lonlat()` replaces its `normalise` argument
  with `as_dataframe` (default `FALSE`). When `FALSE`, centroids are
  returned as a `wk::xy()` vector with WGS 84 CRS; when `TRUE`, as a
  base `data.frame` with `lon`/`lat` columns. The previous `normalise`
  argument toggled longitude normalisation, but upstream a5 (>= 0.7.3)
  always returns normalised longitudes, so the flag's effective job
  collapsed to "what container?". `as_dataframe` makes that explicit.
  Defaults are unchanged for users who never set `normalise` (still
  returns `wk::xy`); explicit `normalise = TRUE`/`FALSE` calls now
  error and must be updated.
* New `lifecycle` dependency added to `Imports`.

# a5R 0.3.1

* `a5_cell()` now requires hex strings to be exactly 16 characters,
  preventing silent construction of wrong cells from truncated input.
* Improved vignettes covering the new `a5_cell` representation and Arrow
  integration.

# a5R 0.3.0

* `a5_cell` internal representation now uses 8 parallel raw byte vectors
  instead of hex strings, reducing memory from ~80 bytes/cell to 8
  bytes/cell (#12).
* `a5_cell` gains `vec_proxy_compare()` and `vec_proxy_order()` methods,
  enabling `sort()`, `order()`, `unique()`, `duplicated()`, `match()`,
  and `%in%` (#12).
* `a5_cell` gains an `is.na()` method (#12).
* New `a5_cell_from_arrow()` and `a5_cell_to_arrow()` for lossless
  conversion between `a5_cell` and Arrow `uint64` arrays, enabling
  zero-copy Parquet I/O (#12).
* New `a5_u64_to_hex()` and `a5_hex_to_u64()` for explicit conversion
  between `a5_cell` vectors and hex strings.
* `a5_is_cell()` has been renamed to `a5_is_valid()` and now accepts
  both `a5_cell` vectors and character hex strings.
* `a5_cell_distance()` and `a5_cell_area()` gain a `units = NULL`
  option to return plain numeric vectors without `units` class
  overhead.
* New vignettes: `vignette("internal-cell-representation")` and
  `vignette("arrow-parquet")`.

# a5R 0.2.0

* Initial CRAN submission.
