# Arrow conversion: not in the other ports' suites. Stored cells reach R as
# Arrow uint64 columns, so these calls bound the cost of any workflow over
# Parquet or DuckDB data.
if (requireNamespace("arrow", quietly = TRUE)) {
  N <- 65536L
  cells <- sample_cells(18L, N)
  arr <- a5_cell_to_arrow(cells)

  bench_group("arrow")
  bench_case("cellToArrow", a5_cell_to_arrow(cells), n = N)
  bench_case("cellFromArrow", a5_cell_from_arrow(arr), n = N)

  # Only on a5R >= 1.0, which added coverings.
  if (exists("a5_union")) {
    disks <- a5_grid_disk(cells[seq_len(256L)], k = 3L)
    disks_arr <- a5_covering_to_arrow(disks)
    bench_case("coveringToArrow", a5_covering_to_arrow(disks), n = 256L)
    bench_case("coveringFromArrow", a5_covering_from_arrow(disks_arr), n = 256L)
  }
}
