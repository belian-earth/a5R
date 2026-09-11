# Hex conversion: mirrors benches/hex.rs.
N <- 256L
cells <- sample_cells(15L, N)
hex <- as.character(cells)

bench_group("hex")
bench_case("u64ToHex", as.character(cells), n = N)
bench_case("hexToU64", a5_cell(hex), n = N)
