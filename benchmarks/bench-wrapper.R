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
