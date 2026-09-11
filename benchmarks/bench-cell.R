# Indexing: mirrors benchmarks/cell.bench.ts and benches/cell.rs.
# Each case is one vectorised call over N sampled points or cells.
N <- 256L
points <- sample_points(N)

bench_group("lonLatToCell")
for (res in c(5L, 15L, 30L)) {
  bench_case(sprintf("lonLatToCell res %d", res),
             a5_lonlat_to_cell(points$lon, points$lat, resolution = res), n = N)
}

bench_group("cellToLonLat")
for (res in c(5L, 15L, 30L)) {
  cells <- sample_cells(res, N)
  bench_case(sprintf("cellToLonLat res %d", res), a5_cell_to_lonlat(cells), n = N)
}

bench_group("cellToBoundary")
for (res in c(5L, 15L, 30L)) {
  cells <- sample_cells(res, N)
  bench_case(sprintf("cellToBoundary res %d", res), a5_cell_to_boundary(cells), n = N)
}
cells15 <- sample_cells(15L, N)
bench_case("cellToBoundary res 15 segments 10",
           a5_cell_to_boundary(cells15, segments = 10L), n = N)
bench_case("cellToBoundary res 15 wkt", a5_cell_to_boundary(cells15, format = "wkt"), n = N)
