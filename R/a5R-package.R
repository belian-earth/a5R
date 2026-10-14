#' @title a5R: A5 Pentagonal Geospatial Index for R
#'
#' @description
#' R bindings for the [A5](https://a5geo.org/) pentagonal geospatial index /
#' discrete global grid system, powered by the a5 Rust crate via extendr.
#'
#' @section Cell type:
#' - [a5_cell()] --- construct cell ID vectors
#' - [is_a5_cell()][a5_cell] --- type test
#' - [a5_is_valid_cell()][a5_is_valid] / [a5_is_valid()] --- validation
#' - [a5_migrate()] --- convert ids from a5R before 1.0
#' - [a5_u64_to_hex()] / [a5_hex_to_u64()][a5_u64_to_hex] --- hex string
#'   conversion
#'
#' @section Indexing:
#' - [a5_lonlat_to_cell()] --- coordinates to cell IDs
#' - [a5_cell_to_lonlat()] --- cell IDs to centre coordinates
#'
#' @section Geometry:
#' - [a5_cell_to_boundary()] --- cell boundary polygons (WKB or WKT)
#' - [a5_cell_to_boundary_xy()] --- cell boundary vertices as flat vectors
#' - [a5_cell_area()] --- cell area at a given resolution
#' - [a5_cell_edge_length_avg()] --- average cell edge length at a resolution
#' - [a5_cell_distance()] --- distance between cell centroids
#' - [a5_get_num_cells()] --- total cell count at a resolution
#' - [a5_get_num_children()] --- child count between resolutions
#'
#' @section Hierarchy:
#' - [a5_get_resolution()] --- extract resolution from cell IDs
#' - [a5_cell_to_parent()] --- navigate to coarser cells
#' - [a5_cell_to_children()] --- navigate to finer cells
#' - [a5_cell_to_supercell()] / [a5_cell_to_subcell()][a5_spatial_hierarchy]
#'   --- move between resolutions by location
#' - [a5_get_res0_cells()] --- the 12 root cells
#'
#' @section Coverings:
#' - [a5_covering] --- compacted cell sets that record their resolution
#' - [a5_compact()] / [a5_uncompact()][a5_compaction] --- build and expand
#'   coverings
#' - [a5_covering_resolution()][a5_covering] --- the resolution a covering
#'   stands for
#' - [a5_covering_stored()] --- the compacted cells a covering stores
#' - [a5_union()] / [a5_intersect()][a5_set_operations] /
#'   [a5_difference()][a5_set_operations] --- combine coverings
#' - [a5_contains()] / [a5_overlaps()][a5_covering_predicates] --- test
#'   coverings
#' - [a5_count()] / [a5_area()][a5_covering_measures] --- measure coverings
#'
#' @section Traversal:
#' - [a5_grid_disk()] --- neighbours by hop count
#' - [a5_spherical_cap()] --- neighbours by great-circle distance
#'
#' @section Geometry indexing:
#' - [a5_polygon_to_cells()] --- cells inside (or overlapping) a polygon
#' - [a5_linestring_to_cells()] --- cells crossed by a great-circle polyline
#'
#' @section Arrow & Parquet:
#' - [a5_cell_from_arrow()] / [a5_cell_to_arrow()][a5_cell_from_arrow] ---
#'   lossless conversion to/from Arrow `uint64`
#' - [a5_covering_from_arrow()] /
#'   [a5_covering_to_arrow()][a5_covering_from_arrow] --- coverings to/from
#'   Arrow `list<uint64>`
#'
#' @section Configuration:
#' - [a5_set_threads()] / [a5_get_threads()] --- multi-threading control
#'
#' @section Vignettes:
#' - `vignette("a5R")` --- getting started
#' - `vignette("coverings")` --- sets of cells: build, combine, test, measure
#' - `vignette("spatial-hierarchy")` --- moving between resolutions by location
#' - `vignette("traversal-and-distance")` --- disks, caps and distances
#' - `vignette("multithreading")` --- parallel processing
#' - `vignette("internal-cell-representation")` --- how cell IDs are stored
#' - `vignette("arrow-parquet")` --- Arrow and Parquet interop
#'
#' @keywords internal
"_PACKAGE"
