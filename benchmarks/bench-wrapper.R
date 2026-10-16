# R wrapper overhead: single-element calls, where the cost is dominated by
# argument handling and result construction rather than the Rust core. Not in
# the other ports; guards the fast paths in R/.
cell <- a5_lonlat_to_cell(-0.1276, 51.5072, resolution = 15L)

bench_group("wrapper")
bench_case("lonLatToCell scalar", a5_lonlat_to_cell(-0.1276, 51.5072, resolution = 15L))
bench_case("cellToLonLat scalar", a5_cell_to_lonlat(cell))
bench_case("cellToParent scalar", a5_cell_to_parent(cell))
bench_case("cellToChildren scalar", a5_cell_to_children(cell))
bench_case("cellToBoundary scalar", a5_cell_to_boundary(cell))
bench_case("cellArea scalar", a5_cell_area(15L))
bench_case("cellDistance scalar", a5_cell_distance(cell, a5_cell_to_parent(cell)))

# Coverings: single calls, where R-side coercion, recycling checks and error
# handling dominate. Only on a5R >= 1.0: before it these functions returned
# plain cells, so a baseline run would time something else under the same name.
if (exists("a5_union")) {
  disk <- a5_grid_disk(cell, k = 1L)
  bench_case("cellToSupercell scalar", a5_cell_to_supercell(cell, resolution = 10L))
  bench_case("cellToSubcells scalar", a5_cell_to_subcells(cell))
  bench_case("uncompact scalar", a5_uncompact(disk))
  bench_case("union scalar", a5_union(disk, disk))
  bench_case("contains scalar", a5_contains(disk, cell))
  bench_case("count scalar", a5_count(disk))
  bench_case("format covering scalar", format(disk))
}
bench_case("gridDisk scalar", a5_grid_disk(cell, k = 1L))
