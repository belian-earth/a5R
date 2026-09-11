# Compaction: mirrors benches/compact.rs.
uk <- load_country("United Kingdom")
compacted <- a5_polygon_to_cells(uk, resolution = 10L)
flat <- a5_uncompact(compacted, resolution = 10L)

bench_group("compact")
bench_case(sprintf("compact UK res 10 (%d cells)", length(flat)), a5_compact(flat), n = length(flat))
bench_case(sprintf("uncompact UK res 10 -> 12 (%d cells)", length(flat) * 16L),
           a5_uncompact(flat, resolution = 12L), n = length(flat))
