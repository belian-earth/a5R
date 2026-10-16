# Supercells and subcells: mirrors benches/subcell.rs, vectorised over the
# same 64 sample cells (n = 64, so per-cell figures line up).
N <- 64L
cells8 <- sample_cells(8L, N)
cells15 <- sample_cells(15L, N)

bench_group("subcell")
bench_case("cellToSupercell res 15 -> 8", a5_cell_to_supercell(cells15, resolution = 8L), n = N)
bench_case("cellToSubcells res 8 -> 11", a5_cell_to_subcells(cells8, resolution = 11L), n = N)
bench_case("cellToSubcells res 8 -> 16", a5_cell_to_subcells(cells8, resolution = 16L), n = N)
cells18 <- sample_cells(18L, N)
bench_case("coveringToSupercells one cell each res 18 -> 6",
           a5_covering_to_supercells(a5_grid_disk(cells18, 0L), resolution = 6L), n = N)
