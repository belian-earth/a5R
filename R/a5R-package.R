#' @title a5R: A5 Pentagonal Geospatial Index for R
#'
#' @description
#' R bindings for the [A5](https://a5geo.org/) pentagonal geospatial index /
#' discrete global grid system, powered by the a5 Rust crate via extendr.
#'
#' @section Cell type:
#' - [a5_cell()] --- construct cell ID vectors
#' - [is_a5_cell()][a5_cell] / [a5_is_valid()][a5_cell] --- type test and
#'   validation
#' - [a5_u64_to_hex()] / [a5_hex_to_u64()][a5_u64_to_hex] --- hex string
#'   conversion
#'
#' @section Indexing:
#' - [a5_lonlat_to_cell()] --- coordinates to cell IDs
#' - [a5_cell_to_lonlat()] --- cell IDs to centre coordinates
#'
#' @section Geometry:
#' - [a5_cell_to_boundary()] --- cell boundary polygons (WKB or WKT)
#' - [a5_cell_area()] --- cell area at a given resolution
#' - [a5_cell_distance()] --- distance between cell centroids
#' - [a5_get_num_cells()] --- total cell count at a resolution
#' - [a5_get_num_children()] --- child count between resolutions
#'
#' @section Hierarchy:
#' - [a5_get_resolution()] --- extract resolution from cell IDs
#' - [a5_cell_to_parent()] --- navigate to coarser cells
#' - [a5_cell_to_children()] --- navigate to finer cells
#' - [a5_get_res0_cells()] --- the 12 root cells
#' - [a5_compact()] / [a5_uncompact()] --- compress and expand cell sets
#'
#' @section Traversal:
#' - [a5_grid_disk()] --- neighbours by hop count
#' - [a5_spherical_cap()] --- neighbours by great-circle distance
#'
#' @section Grid generation:
#' - [a5_grid()] --- fill a bbox or geometry with cells
#'
#' @section Arrow & Parquet:
#' - [a5_cell_from_arrow()] / [a5_cell_to_arrow()][a5_cell_from_arrow] ---
#'   lossless conversion to/from Arrow `uint64`
#'
#' @section Configuration:
#' - [a5_set_threads()] / [a5_get_threads()] --- multi-threading control
#'
#' @section Vignettes:
#' - `vignette("a5R")` --- getting started
#' - `vignette("multithreading")` --- parallel processing
#' - `vignette("internal-cell-representation")` --- how cell IDs are stored
#' - `vignette("arrow-parquet")` --- Arrow and Parquet interop
#'
#' @keywords internal
"_PACKAGE"
