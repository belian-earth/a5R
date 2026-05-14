# a5R: A5 Pentagonal Geospatial Index for R

R bindings for the [A5](https://a5geo.org/) pentagonal geospatial index
/ discrete global grid system, powered by the a5 Rust crate via extendr.

## Cell type

- [`a5_cell()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  — construct cell ID vectors

- [is_a5_cell()](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  /
  [a5_is_valid()](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  — type test and validation

- [`a5_u64_to_hex()`](https://belian-earth.github.io/a5R/reference/a5_u64_to_hex.md)
  /
  [a5_hex_to_u64()](https://belian-earth.github.io/a5R/reference/a5_u64_to_hex.md)
  — hex string conversion

## Indexing

- [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_lonlat_to_cell.md)
  — coordinates to cell IDs

- [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_lonlat.md)
  — cell IDs to centre coordinates

## Geometry

- [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_boundary.md)
  — cell boundary polygons (WKB or WKT)

- [`a5_cell_area()`](https://belian-earth.github.io/a5R/reference/a5_cell_area.md)
  — cell area at a given resolution

- [`a5_cell_distance()`](https://belian-earth.github.io/a5R/reference/a5_cell_distance.md)
  — distance between cell centroids

- [`a5_get_num_cells()`](https://belian-earth.github.io/a5R/reference/a5_get_num_cells.md)
  — total cell count at a resolution

- [`a5_get_num_children()`](https://belian-earth.github.io/a5R/reference/a5_get_num_children.md)
  — child count between resolutions

## Hierarchy

- [`a5_get_resolution()`](https://belian-earth.github.io/a5R/reference/a5_get_resolution.md)
  — extract resolution from cell IDs

- [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_parent.md)
  — navigate to coarser cells

- [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_children.md)
  — navigate to finer cells

- [`a5_get_res0_cells()`](https://belian-earth.github.io/a5R/reference/a5_get_res0_cells.md)
  — the 12 root cells

- [`a5_compact()`](https://belian-earth.github.io/a5R/reference/a5_compact.md)
  /
  [`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_uncompact.md)
  — compress and expand cell sets

## Traversal

- [`a5_grid_disk()`](https://belian-earth.github.io/a5R/reference/a5_grid_disk.md)
  — neighbours by hop count

- [`a5_spherical_cap()`](https://belian-earth.github.io/a5R/reference/a5_spherical_cap.md)
  — neighbours by great-circle distance

## Geometry indexing

- [`a5_polygon_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_polygon_to_cells.md)
  — cells whose centres lie inside a polygon

- [`a5_linestring_to_cells()`](https://belian-earth.github.io/a5R/reference/a5_linestring_to_cells.md)
  — cells crossed by a great-circle polyline

## Arrow & Parquet

- [`a5_cell_from_arrow()`](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
  /
  [a5_cell_to_arrow()](https://belian-earth.github.io/a5R/reference/a5_cell_from_arrow.md)
  — lossless conversion to/from Arrow `uint64`

## Configuration

- [`a5_set_threads()`](https://belian-earth.github.io/a5R/reference/a5_threads.md)
  /
  [`a5_get_threads()`](https://belian-earth.github.io/a5R/reference/a5_threads.md)
  — multi-threading control

## Vignettes

- [`vignette("a5R")`](https://belian-earth.github.io/a5R/articles/a5R.md)
  — getting started

- [`vignette("multithreading")`](https://belian-earth.github.io/a5R/articles/multithreading.md)
  — parallel processing

- [`vignette("internal-cell-representation")`](https://belian-earth.github.io/a5R/articles/internal-cell-representation.md)
  — how cell IDs are stored

- [`vignette("arrow-parquet")`](https://belian-earth.github.io/a5R/articles/arrow-parquet.md)
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
