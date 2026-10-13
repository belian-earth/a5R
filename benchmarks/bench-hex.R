# Hex conversion: mirrors benches/hex.rs.
N <- 256L
cells <- sample_cells(15L, N)
hex <- as.character(cells)

bench_group("hex")
bench_case("u64ToHex", as.character(cells), n = N)
bench_case("hexToU64", a5_cell(hex), n = N)

# Migration from the v0 index: not in the other ports' suites. The ids are
# v1, migrated as if they were v0: the bit work is the same either way.
if (exists("a5_migrate")) {
  bench_group("migrate")
  bench_case("migrate res 15", a5_migrate(cells), n = N)
}
