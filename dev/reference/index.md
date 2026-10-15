# Package index

## Indexing

Convert between coordinates and A5 cell indices.

- [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/dev/reference/a5_coordinates.md)
  : Convert between coordinates and cells

## Cell type

The `a5_cell` vector type and helpers.

- [`a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  [`is_a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  [`as_a5_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell.md)
  : A5 Cell Index Vector
- [`as_a5_cell_list()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  [`unlist(`*`<a5_cell_list>`*`)`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_list.md)
  : List of A5 cell vectors
- [`a5_is_valid()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  [`a5_is_valid_cell()`](https://belian-earth.github.io/a5R/dev/reference/a5_is_valid.md)
  : Check that values are A5 cells
- [`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  [`a5_hex_to_u64()`](https://belian-earth.github.io/a5R/dev/reference/a5_u64_to_hex.md)
  : Coerce between hex strings and A5 cell vectors
- [`a5_migrate()`](https://belian-earth.github.io/a5R/dev/reference/a5_migrate.md)
  : Migrate cell ids from the pre-1.0 index

## Arrow & Parquet

Lossless conversion to and from Arrow arrays.

- [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  [`a5_cell_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_from_arrow.md)
  : Convert between a5_cell and Arrow uint64 arrays

- [`a5_covering_from_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  [`a5_covering_to_arrow()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_from_arrow.md)
  :

  Convert between a5_covering and Arrow list arrays

- [`a5_to_arrow_table()`](https://belian-earth.github.io/a5R/dev/reference/a5_to_arrow_table.md)
  [`a5_from_arrow_table()`](https://belian-earth.github.io/a5R/dev/reference/a5_to_arrow_table.md)
  : Convert data frames with cell columns to and from Arrow tables

## Hierarchy

Navigate the cell hierarchy across resolutions.

- [`a5_get_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_resolution.md)
  : Get the resolution of A5 cell indices
- [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_hierarchy.md)
  : Index parents and children
- [`a5_cell_to_supercell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  [`a5_cell_to_subcell()`](https://belian-earth.github.io/a5R/dev/reference/a5_spatial_hierarchy.md)
  : Supercells and subcells: parents and children by location
- [`a5_covering_to_supercells()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_to_supercells.md)
  : Supercells of a covering
- [`a5_cell_child()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_child.md)
  : The i-th child of each cell
- [`a5_cell_children_range()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_children_range.md)
  : Range of descendant cell ids
- [`a5_get_res0_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_get_res0_cells.md)
  : Get all resolution-0 root cells

## Geometry & info

Cell boundaries, areas, counts, and distances.

- [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary.md)
  : Get cell boundary polygons
- [`a5_cell_to_boundary_xy()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_to_boundary_xy.md)
  : Get cell boundary vertices as flat coordinate vectors
- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/dev/reference/a5_cell_distance.md)
  : Distance between cell centroids
- [`a5_cell_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  [`a5_cell_edge_length_avg()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  [`a5_get_num_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  [`a5_get_num_children()`](https://belian-earth.github.io/a5R/dev/reference/a5_resolution_stats.md)
  : Cell size and counts by resolution

## Traversal

Neighbourhood and distance-based cell selection.

- [`a5_grid_disk()`](https://belian-earth.github.io/a5R/dev/reference/a5_grid_disk.md)
  : Cells within k hops of a cell
- [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/dev/reference/a5_spherical_cap.md)
  : Cells within a great-circle radius

## Coverings

Compacted sets of cells that record their resolution.

- [`as_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  [`is_a5_covering()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  [`a5_covering_resolution()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering.md)
  : A5 covering vectors
- [`a5_covering_stored()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_stored.md)
  : Stored cells of a covering
- [`a5_compact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  [`a5_uncompact()`](https://belian-earth.github.io/a5R/dev/reference/a5_compaction.md)
  : Compact and uncompact sets of cells
- [`a5_union()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  [`a5_intersect()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  [`a5_difference()`](https://belian-earth.github.io/a5R/dev/reference/a5_set_operations.md)
  : Combine coverings
- [`a5_contains()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
  [`a5_overlaps()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_predicates.md)
  : Test coverings
- [`a5_count()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
  [`a5_area()`](https://belian-earth.github.io/a5R/dev/reference/a5_covering_measures.md)
  : Measure coverings

## Geometry indexing

Convert polygons and linestrings to cells covering them.

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_polygon_to_cells.md)
  : Cells inside or overlapping a polygon
- [`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/dev/reference/a5_linestring_to_cells.md)
  : Cells traced by a great-circle linestring
- [`a5_bbox()`](https://belian-earth.github.io/a5R/dev/reference/a5_bbox.md)
  : Bounding box of polygons with great-circle edges

## Configuration

Package information, thread control, error classes and the C API.

- [`a5_info()`](https://belian-earth.github.io/a5R/dev/reference/a5_info.md)
  : a5R build and session information
- [`a5_set_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  [`with(`*`<a5_threads>`*`)`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  [`a5_get_threads()`](https://belian-earth.github.io/a5R/dev/reference/a5_threads.md)
  : Set the number of threads used by a5R
- [`a5_errors`](https://belian-earth.github.io/a5R/dev/reference/a5_errors.md)
  : Error classes
- [`a5_c_api`](https://belian-earth.github.io/a5R/dev/reference/a5_c_api.md)
  : C API for other packages

## wk integration

Methods for the wk geometry framework.

- [`wk_handle(`*`<a5_cell>`*`)`](https://belian-earth.github.io/a5R/dev/reference/wk_methods.md)
  [`wk_crs(`*`<a5_cell>`*`)`](https://belian-earth.github.io/a5R/dev/reference/wk_methods.md)
  : wk methods for a5_cell
