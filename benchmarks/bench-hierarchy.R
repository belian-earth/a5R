# Hierarchy and cell info: mirrors benches/hierarchy.rs.
N <- 256L
cells15 <- sample_cells(15L, N)
cells10 <- sample_cells(10L, N)

bench_group("hierarchy")
bench_case("getResolution res 15", a5_get_resolution(cells15), n = N)
bench_case("cellToParent res 15 -> 14", a5_cell_to_parent(cells15), n = N)
bench_case("cellToParent res 15 -> 5", a5_cell_to_parent(cells15, resolution = 5L), n = N)
bench_case("cellToChildren res 15 -> 16", a5_cell_to_children(cells15), n = N)
bench_case("cellToChildren res 10 -> 13", a5_cell_to_children(cells10, resolution = 13L), n = N)
bench_case("cellToChildren res 10 -> 13 list", a5_cell_to_children(cells10, resolution = 13L, simplify = FALSE), n = N)
bench_case("cellChild res 10 -> 13", a5_cell_child(cells10, resolution = 13L, i = 7L), n = N)
bench_case("cellChildrenRange res 10 -> 16", a5_cell_children_range(cells10, resolution = 16L), n = N)
bench_case("getRes0Cells", a5_get_res0_cells())

bench_group("cell-info")
bench_case("getNumCells res 15", a5_get_num_cells(15L))
bench_case("getNumChildren res 0 -> 15", a5_get_num_children(0L, 15L))
bench_case("cellArea res 15", a5_cell_area(15L))
bench_case("cellArea res 15 km2", a5_cell_area(15L, units = "km^2"))
bench_case("cellEdgeLengthAvg res 15", a5_cell_edge_length_avg(15L))
