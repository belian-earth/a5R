# Package index

## Indexing

Convert between coordinates and A5 cell indices.

- [`a5_lonlat_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_lonlat_to_cell.md)
  : Convert coordinates to A5 cell indices
- [`a5_cell_to_lonlat()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_lonlat.md)
  : Convert A5 cell indices to coordinates

## Cell type

The `a5_cell` vector type and helpers.

- [`a5_cell()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  [`is_a5_cell()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  [`as_a5_cell()`](https://belian-earth.github.io/a5R/reference/a5_cell.md)
  : A5 Cell Index Vector
- [`a5_hex_to_cell()`](https://belian-earth.github.io/a5R/reference/a5_hex_to_cell.md)
  : Convert hex string to A5 cell
- [`a5_is_cell()`](https://belian-earth.github.io/a5R/reference/a5_is_cell.md)
  : Test if values are valid A5 cell indices

## Hierarchy

Navigate the cell hierarchy across resolutions.

- [`a5_get_resolution()`](https://belian-earth.github.io/a5R/reference/a5_get_resolution.md)
  : Get the resolution of A5 cell indices
- [`a5_cell_to_parent()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_parent.md)
  : Navigate to parent cell(s)
- [`a5_cell_to_children()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_children.md)
  : Get child cells
- [`a5_get_res0_cells()`](https://belian-earth.github.io/a5R/reference/a5_get_res0_cells.md)
  : Get all resolution-0 root cells

## Geometry & info

Cell boundaries, areas, and counts.

- [`a5_cell_to_boundary()`](https://belian-earth.github.io/a5R/reference/a5_cell_to_boundary.md)
  : Get cell boundary polygons
- [`a5_cell_area()`](https://belian-earth.github.io/a5R/reference/a5_cell_area.md)
  : Cell area at a given resolution
- [`a5_get_num_cells()`](https://belian-earth.github.io/a5R/reference/a5_get_num_cells.md)
  : Total number of cells at a given resolution

## Compact & uncompact

Compress and expand sets of cells.

- [`a5_compact()`](https://belian-earth.github.io/a5R/reference/a5_compact.md)
  : Compact a set of A5 cells
- [`a5_uncompact()`](https://belian-earth.github.io/a5R/reference/a5_uncompact.md)
  : Uncompact a set of A5 cells to a target resolution

## Grid generation

Generate grids of cells covering an area.

- [`a5_grid()`](https://belian-earth.github.io/a5R/reference/a5_grid.md)
  : Generate a grid of A5 cells covering an area

## wk integration

Methods for the wk geometry framework.

- [`wk_handle(`*`<a5_cell>`*`)`](https://belian-earth.github.io/a5R/reference/wk_methods.md)
  [`wk_crs(`*`<a5_cell>`*`)`](https://belian-earth.github.io/a5R/reference/wk_methods.md)
  : wk methods for a5_cell
