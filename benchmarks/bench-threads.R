# Multi-threaded paths: the rayon dispatch behind a5_set_threads(). Two
# threads, which GitHub-hosted runners provide; single-threaded counterparts
# of the same calls sit alongside so the ratio is visible in the report.
# Timings here are more sensitive to a shared runner's load than the rest of
# the suite.
N <- 10000L
points <- sample_points(N)
cells <- a5_lonlat_to_cell(points$lon, points$lat, resolution = 12L)
cells9 <- vctrs::vec_slice(sample_cells(9L, 256L), seq_len(256L))

bench_group("threads")
for (threads in c(1L, 2L)) {
  a5_set_threads(threads)
  bench_case(sprintf("lonLatToCell 10k res 12 threads=%d", threads),
             a5_lonlat_to_cell(points$lon, points$lat, resolution = 12L), n = N)
  bench_case(sprintf("cellToLonLat 10k threads=%d", threads), a5_cell_to_lonlat(cells), n = N)
  bench_case(sprintf("cellToBoundary 10k threads=%d", threads), a5_cell_to_boundary(cells), n = N)
  bench_case(sprintf("gridDisk k=1 x256 list threads=%d", threads),
             a5_grid_disk(cells9, k = 1L, simplify = FALSE), n = 256L)
}
a5_set_threads(1L)
