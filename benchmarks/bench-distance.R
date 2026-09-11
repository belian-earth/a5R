# Distance and validity, vectorised over sampled cells.
N <- 256L
from <- sample_cells(12L, N, seed = 42)
to <- sample_cells(12L, N, seed = 7)
hex <- as.character(from)

bench_group("cellDistance")
for (method in c("haversine", "geodesic", "rhumb")) {
  bench_case(sprintf("cellDistance %s", method),
             a5_cell_distance(from, to, method = method), n = N)
}
bench_case("cellDistance haversine no units", a5_cell_distance(from, to, units = NULL), n = N)

bench_group("isValid")
bench_case("isValid cells", a5_is_valid(from), n = N)
bench_case("isValid hex", a5_is_valid(hex), n = N)
