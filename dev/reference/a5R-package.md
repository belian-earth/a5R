# a5R: A5 Pentagonal Geospatial Index for R

R bindings for the [A5](https://a5geo.org/) pentagonal geospatial index
/ discrete global grid system, powered by the a5 Rust crate via extendr.

## Cell type

- [`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  — construct cell ID vectors

- [is_a5_cell()](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  — type test

- [a5_is_valid_cell()](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  /
  [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  — validation

- [`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md)
  — convert ids from a5R before 1.0

- [`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  /
  [a5_hex_to_u64()](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  — hex string conversion

## Indexing

- [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  — coordinates to cell IDs

- [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  — cell IDs to centre coordinates

## Geometry

- [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  — cell boundary polygons (WKB or WKT)

- [`a5_cell_to_boundary_xy()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary_xy.md)
  — cell boundary vertices as flat vectors

- [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  — cell area at a given resolution

- [`a5_cell_edge_length_avg()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  — average cell edge length at a resolution

- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  — distance between cell centroids

- [`a5_get_num_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  — total cell count at a resolution

- [`a5_get_num_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  — child count between resolutions

## Hierarchy

- [`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md)
  — extract resolution from cell IDs

- [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  — navigate to coarser cells

- [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  — navigate to finer cells

- [`a5_cell_to_supercell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  /
  [a5_cell_to_subcells()](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  — move between resolutions by location

- [`a5_get_res0_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_res0_cells.md)
  — the 12 root cells

## Coverings

- [a5_covering](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  — compacted cell sets that record their resolution

- [`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  /
  [a5_uncompact()](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  — build and expand coverings

- [a5_covering_resolution()](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  — the resolution a covering stands for

- [`a5_covering_stored()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_stored.md)
  — the compacted cells a covering stores

- [`a5_union()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  /
  [a5_intersect()](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  /
  [a5_difference()](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  — combine coverings

- [`a5_contains()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
  /
  [a5_overlaps()](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
  — test coverings

- [`a5_count()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
  /
  [a5_area()](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
  — measure coverings

## Traversal

- [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  — neighbours by hop count

- [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  — neighbours by great-circle distance

## Geometry indexing

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  — cells inside (or overlapping) a polygon

- [`a5_line_string_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_line_string_to_cells.md)
  — cells crossed by a great-circle polyline

## Arrow & Parquet

- [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  /
  [a5_cell_to_arrow()](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  — lossless conversion to/from Arrow `uint64`

- [`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  /
  [a5_covering_to_arrow()](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  — coverings to/from Arrow `list<uint64>`

## Configuration

- [`a5_set_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  /
  [`a5_get_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  — multi-threading control

## Vignettes

- [`vignette("a5R")`](https://belian-earth.github.io/a5R/dev/articles/a5R.md)
  — getting started

- [`vignette("coverings")`](https://belian-earth.github.io/a5R/dev/articles/coverings.md)
  — sets of cells: build, combine, test, measure

- [`vignette("spatial-hierarchy")`](https://belian-earth.github.io/a5R/dev/articles/spatial-hierarchy.md)
  — moving between resolutions by location

- [`vignette("traversal-and-distance")`](https://belian-earth.github.io/a5R/dev/articles/traversal-and-distance.md)
  — disks, caps and distances

- [`vignette("multithreading")`](https://belian-earth.github.io/a5R/dev/articles/multithreading.md)
  — parallel processing

- [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/dev/articles/internal-cell-representation.md)
  — how cell IDs are stored

- [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/dev/articles/arrow-parquet.md)
  — Arrow and Parquet interop

## See also

Useful links:

- <https://github.com/belian-earth/a5R>

- <https://belian-earth.github.io/a5R/>

- Report bugs at <https://github.com/belian-earth/a5R/issues>

## Author

**Maintainer**: Hugh Graham <hugh@belian.earth>

Authors:

- Hugh Graham <hugh@belian.earth>

Other contributors:

- belian.earth \[copyright holder\]

- Felix Palmer (Author of the bundled 'a5' Rust crate) \[contributor,
  copyright holder\]

- Authors of the dependency Rust crates (see LICENSE.note) \[copyright
  holder\]
