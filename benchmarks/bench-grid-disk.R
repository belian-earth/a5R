# Traversal: mirrors benches/grid_disk.rs.
london <- a5_lonlat_to_cell(-0.1276, 51.5072, resolution = 9L)

bench_group("gridDisk")
for (k in c(1L, 5L, 20L)) {
  bench_case(sprintf("gridDisk k=%d", k), a5_grid_disk(london, k = k))
}
bench_case("gridDiskVertex k=5", a5_grid_disk(london, k = 5L, vertex = TRUE))
cells9 <- sample_cells(9L, 64L)
bench_case("gridDisk k=1 x64 list", a5_grid_disk(cells9, k = 1L, simplify = FALSE), n = 64L)
