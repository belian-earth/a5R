# Changelog

## a5R (development version)

### Breaking changes

- a5R now uses the a5 Rust crate 1.0.0, which introduces A5’s permanent
  cell-ID system. The space-filling curve and the order of the
  dodecahedron faces are new, so **every cell id changes**: an id
  written by an earlier version of a5R is still a valid cell, but in a
  different place, and nothing in the id says which version wrote it.
  Re-index stored data from its coordinates, or convert the ids once
  with the new
  [`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md).
- Resolution-1 cells are now pentagons rather than triangles, so their
  boundaries and centres change. Cells at every other resolution keep
  their shape and position.
- Compacted cell sets are now `a5_covering` vectors, one covering per
  element. A covering stores its compacted cells followed by a
  compaction marker recording the resolution they stand for, as in the
  other A5 libraries, so
  [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  no longer needs a resolution. Coverings print as their resolution,
  cell count and stored-cell count, work as data frame columns, and
  compare equal with `==` when they hold the same cells. Use
  [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  for the cells;
  [`as_a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  refuses a covering rather than treat its stored cells, whose outlines
  do not nest, as a grid.
- [`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md),
  [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  return coverings.
  [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  give one covering per centre cell and lose their `simplify` argument,
  which moves to
  [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md).
  An `NA` centre gives an `NA` covering.
- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  returns one covering per feature instead of the union of all features,
  so it can fill a column of an `sf` data frame. A feature’s parts and
  holes are still combined. A missing geometry gives an `NA` covering
  and an empty geometry an empty covering; both used to be errors.
- [`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_linestring_to_cells.md)
  is renamed
  [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md),
  to match `line_string_to_cells()` in the other A5 libraries. The old
  name still works but warns.
- [`a5_set_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_threads.md)
  and
  [`a5_get_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_threads.md)
  are replaced by
  [`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md),
  which sets the count when given one and reports it otherwise, as
  [`options()`](https://rdrr.io/r/base/options.html) and
  [`par()`](https://rdrr.io/r/graphics/par.html) do. The old functions
  still work but warn.
- [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  loses its `vertex` argument. Use the new
  [`a5_grid_disk_vertex()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md),
  which matches `grid_disk_vertex()` in the other A5 libraries, for
  vertex-sharing neighbours.
- Arguments take the names used by the a5 crate and a5-js: `resolution`
  becomes `parent_resolution` in
  [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  and `child_resolution` in
  [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md),
  and `closed` becomes `closed_ring` in
  [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  and
  [`a5_cell_to_boundary_xy()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary_xy.md).
  The old names still work but warn.
  [`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
  and
  [`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
  also take `child_resolution`.
- [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md),
  [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md),
  [`a5_cell_to_boundary_xy()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary_xy.md)
  and
  [`a5_cell_to_supercell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  error on an id that is not an A5 cell, as the a5 crate and a5R’s other
  functions do. They used to return `NA` or an empty boundary.
- [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md)
  gains `simplify`: with `simplify = FALSE` it returns an `a5_cell_list`
  with one ordered path per feature, for a list column. The default flat
  form concatenates the paths, so a cell crossed by several features now
  appears once per feature rather than once overall; within a feature,
  each cell still appears once. Missing and empty geometries contribute
  no cells instead of an error.
- [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  takes coverings, and its `resolution` argument is optional: by default
  each covering expands to its own resolution. It refuses to build more
  than `.Machine$integer.max` cells.
- [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  now checks the index encoding. It used to return `TRUE` for any
  non-missing `a5_cell` and for any hex string that parsed, whether or
  not the value was a cell. Hex strings are read as
  [`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  reads them, so unpadded ids, as the a5 crate writes them, are
  accepted.
- [`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)’s
  first argument is now `cell`, as in other functions that take cells,
  rather than `cells`.

### New features

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  accepts `containment = "center"` as well as `"centre"`, and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  gains `units`, taking the radius in any length unit or as a `units`
  object.
- Errors have class `a5R_error` and a subclass naming what went wrong,
  such as `a5R_error_resolution` or `a5R_error_geometry`, so code can
  handle them without matching messages. See
  [`?a5_errors`](https://belian-earth.github.io/a5R/dev/reference/a5_errors.md).
- New
  [`a5_info()`](https://belian-earth.github.io/a5R/dev/reference/a5_info.md)
  gives the a5R, bundled a5 crate, A5 index and C API versions and the
  thread count, as a list that prints as a summary. The same summary is
  shown on one line when a5R is attached. Record its `index` with stored
  cells.
- a5R exports a C API (`a5R.h`, see
  [`?a5_c_api`](https://belian-earth.github.io/a5R/dev/reference/a5_c_api.md))
  for packages that convert between 64-bit ids and `a5_cell` vectors in
  compiled code, so they need not rely on how `a5_cell` stores its data.
- New
  [`a5_bbox()`](https://belian-earth.github.io/a5R/dev/reference/a5_bbox.md)
  gives the longitude/latitude box of polygons as A5 sees them, with
  great-circle edges that can bow beyond the vertices’ latitudes.
- New
  [`a5_covering_to_supercells()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_to_supercells.md)
  gives the coarse cells containing the centres of a covering’s cells
  without building them.
- `with(a5_threads(n), expr)` runs `expr` on `n` threads and restores
  the previous count afterwards, as `with(mirai::daemons(n), expr)`
  does. `a5_threads(n)` returns the previous count as an `a5_threads`
  object to make this work.
- New
  [`a5_to_arrow_table()`](https://belian-earth.github.io/a5R/dev/reference/a5_to_arrow_table.md)
  and
  [`a5_from_arrow_table()`](https://belian-earth.github.io/a5R/dev/reference/a5_to_arrow_table.md)
  convert data frames with cell and covering columns to and from Arrow
  tables, tagging the table with the index version and refusing tables
  from another index.
- New
  [`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md)
  converts ids from a5R before 1.0 to the current index.
- New
  [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  builds coverings from cells, cell lists or raw 64-bit values written
  by other A5 libraries, sorting and compacting them;
  [`a5_covering_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  returns the resolution each covering stands for.
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  checks covering structure.
- New covering operations, computed on the compacted cells without
  expanding them:
  [`a5_union()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md),
  [`a5_intersect()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  and
  [`a5_difference()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  combine coverings element by element, and `a5_union(x)` merges every
  covering in `x`;
  [`a5_contains()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
  tests cells against coverings (a point-in-polygon test at the
  covering’s resolution) and
  [`a5_overlaps()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
  tests pairs of coverings;
  [`a5_count()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
  and
  [`a5_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
  give the number of cells and the area each covering stands for.
  Combining coverings at different resolutions is an error, as upstream.
- New
  [`a5_covering_stored()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_stored.md)
  returns the compacted cells a covering stores, without the compaction
  marker, for index range queries with
  [`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md).
- New
  [`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  and
  [`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  convert coverings to and from Arrow `list<uint64>` with the compaction
  marker, the layout DuckDB, Python and JavaScript A5 code read.
- New
  [`a5_is_valid_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  checks that values are A5 cells, mirroring the upstream
  `is_valid_cell`.
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  becomes a generic that also accepts an `a5_cell_list`, returning one
  value per element.
- New
  [`a5_cell_to_boundary_xy()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary_xy.md)
  returns the boundary vertices of many cells as flat `x` and `y`
  vectors with per-cell `lengths`, ready for a single
  [`grid::polygonGrob()`](https://rdrr.io/r/grid/grid.polygon.html). It
  skips building a geometry per cell, so it is about 1.5 times faster
  than
  [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  followed by
  [`wk::wk_coords()`](https://paleolimbot.github.io/wk/reference/wk_vertices.html)
  on one thread, 3 times faster on four, and allocates an eighth of the
  memory.

### Other changes

- As in the other A5 libraries,
  [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md)
  gives the cell containing a single waypoint, and
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  gives an empty covering for an outer ring of fewer than 3 distinct
  vertices and ignores such holes. Both used to error.

- [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  accepts `resolution = -1`, giving the world cell.

- The a5 crate 1.0.0 fixes two wrong results.
  [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  with `containment = "centre"` no longer returns a whole quintant of
  cells for thin sliver polygons, and
  [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  no longer returns a cell on the wrong dodecahedron face when the
  previous point fell near the centre of another face.

- Functions returning many cells write them straight into R’s vectors,
  in parallel when threads are enabled, instead of staging them first:
  [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  is about 2.5 times faster on millions of cells, and
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  and
  [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  up to a third faster, with lower peak memory.

- [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  returns `NA` for `NaN` and infinite coordinates, which used to give
  valid cells, and errors on latitudes outside \[-90, 90\], which used
  to wrap onto plausible but wrong cells.

- [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md),
  [`a5_grid_disk_vertex()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  return the world cell’s covering for the world cell, which is its own
  disk and cap. They used to fail with a Rust panic.

- Forked workers
  ([`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html),
  `future::multicore`) no longer hang after
  [`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  sets more than one thread: they inherited the thread pool but not its
  threads. a5R now runs on one thread in a forked worker until the
  worker sets its own count.

- A panic inside the a5 crate during a multi-threaded call no longer
  leaves every later parallel call, and
  [`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md),
  failing until R restarts.
  [`a5_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  rejects counts below 1 and `NA`, and keeps the previous count if the
  thread pool cannot be built.

- [`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  accepts ids of fewer than 16 hex digits, as written by a5-js and
  DuckDB, and a `0x` prefix. A string that is not a hex id is now an
  error instead of a silent `NA`.

- `NA` cells are missing to vctrs: `==` against `NA` gives `NA`, and
  sorting puts `NA` last instead of among the resolution-30 cells.

- [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  treats `NULL` list elements as missing coverings, so null coverings
  read back from Arrow stay `NA` instead of becoming empty.

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  and
  [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md)
  error on `sf` and `terra` input in a projected CRS, and on coordinates
  outside the longitude/latitude range. The documentation now warns that
  self-intersecting rings give undefined results.

- [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  rejects a negative or `NA` `k`, and
  [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  a negative or non-finite `radius`.

- [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)’s
  size guard counts the 5 children of a resolution-0 cell, so it no
  longer lets through requests up to 25% over the limit.

- Scalar resolution arguments reject `NA` with a clear error, and
  [`a5_get_num_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  errors when the child resolution is coarser than the parent instead of
  returning 0.

- [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  and
  [`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  give a clear error for input that is not an Arrow array.

- [`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
  and
  [`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
  reach resolution 29 from any cell, as documented, instead of erroring
  beyond 20 levels.

- The world cell’s boundary is `POLYGON EMPTY` instead of an invalid
  polygon.

- [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  errors when `resolution` is finer than a cell’s resolution, instead of
  returning a descendant.

- [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  builds its output faster, with identical results: on a million cells,
  WKB takes about 25% less time on one thread and half the time on four,
  and WKT about 20% less.

- [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  rejects a `segments` value below 1 or `NA`; a negative value used to
  hang. Its documentation now gives the default,
  `max(1, 2^(6 - resolution))` segments per edge, and how far a single
  segment strays from the curved cell edge at each resolution.

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  handles
  [`wk::rct()`](https://paleolimbot.github.io/wk/reference/rct.html)
  boxes that previously gave wrong results. A box covering the whole
  globe gives every cell instead of none, and a box reaching from pole
  to pole keeps its west and east edges on their meridians. Any other
  box spanning 180 degrees of longitude or more is an error, because its
  great-circle edges would run the short way round. The documentation
  now states that polygon edges are great circles.

- New
  [`vignette("coverings")`](https://belian-earth.github.io/a5R/dev/articles/coverings.md)
  on building, combining, testing and measuring coverings.
  [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/dev/articles/arrow-parquet.md)
  covers storing coverings and migrating data written before 1.0, and
  [`vignette("spatial-hierarchy")`](https://belian-earth.github.io/a5R/dev/articles/spatial-hierarchy.md)
  is rewritten for supercells and subcells.

- [`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md),
  [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md),
  [`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  and
  [`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  run in Rust and pass one contiguous `uint64` buffer through the Arrow
  C data interface, instead of building an R object per cell. On 10
  million cells, writing to Arrow is about 90 times faster and reading
  about 40 times faster.
  [`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  now refuses a covering that holds a null cell; it used to drop the
  null silently.

- [`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
  and
  [`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
  follow the new order of
  [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  (children are now in ascending id order).

- [`a5_get_num_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  is correct at high resolutions (a5 0.10.1).

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  merges a feature’s parts with the upstream covering union, without
  expanding each part to full resolution first.

- New
  [`a5_cell_to_supercell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  and
  [`a5_cell_to_subcells()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  move between resolutions by cell centre rather than by index, wrapping
  the upstream `cell_to_supercell()` and `cell_to_subcells()`. The A5
  index hierarchy is not spatially nested: for about half of cells one
  resolution apart, and about 35% at four or more apart, the index
  parent is not the coarse cell containing the fine cell’s centre.
  Supercells and subcells form an exact partition, so aggregating fine
  cells to a coarser grid counts each fine cell once, inside the coarse
  cell it lies in. Subcells are returned as one covering per cell.
  [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  and
  [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  are unchanged and now document the difference.

- Missing values filled in by vctrs are now `NA`, not the world cell
  ([\#27](https://github.com/belian-earth/a5R/issues/27)). Combining
  with `NA`, subsetting with an `NA` index, assigning `NA`,
  [`vctrs::vec_init()`](https://vctrs.r-lib.org/reference/vec_init.html),
  and unmatched rows from `merge(all = TRUE)`,
  [`vctrs::vec_rbind()`](https://vctrs.r-lib.org/reference/vec_bind.html)
  or dplyr joins used to produce id 0, a valid cell. The top byte of
  each id is now stored XOR `0xFC`, so a filled-in gap decodes to the NA
  sentinel, at no measurable cost. This changes the stored byte layout:
  `a5_cell` objects saved with
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html),
  [`save()`](https://rdrr.io/r/base/save.html) or qs by earlier versions
  do not read correctly. Re-create them from hex strings or Arrow, which
  store the true id.

- Resolution-30 cells whose id starts with `0xFC` (about 0.3% of them,
  in quintants 31, 39 and 41) are no longer treated as `NA`. The NA
  check now compares the full id rather than its top byte.

- The benchmark suite now mirrors the TypeScript, Python and Rust A5
  ports (same case names, same deterministic inputs) and runs in CI on
  every pull request, failing on regressions above 15%. The old
  cross-language comparison scripts are gone.

- [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md),
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

- Base R compatibility for `a5_cell`:
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
  [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  casts and recycles common inputs without vctrs,
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  uses low-level `wk` and data frame constructors, and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md),
  [`a5_cell_edge_length_avg()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
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
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md).
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
  [`a5_cell_edge_length_avg()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
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
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
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
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  and now accepts both `a5_cell` vectors and character hex strings.
- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  and
  [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  gain a `units = NULL` option to return plain numeric vectors without
  `units` class overhead.
- New vignettes:
  [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/dev/articles/internal-cell-representation.md)
  and
  [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/dev/articles/arrow-parquet.md).

## a5R 0.2.0

CRAN release: 2026-03-16

- Initial CRAN submission.
