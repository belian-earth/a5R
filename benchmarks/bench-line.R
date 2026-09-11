# Lines: mirrors benches/line.rs.
london_paris <- wk::wkt("LINESTRING (-0.1276 51.5072, 2.3522 48.8566)")
round_the_world <- wk::wkt(paste0(
  "LINESTRING (-122.4194 37.7749, -74.006 40.7128, -0.1276 51.5072, ",
  "139.6917 35.6895, 151.2093 -33.8688)"
))

bench_group("lineStringToCells")
bench_case("lineStringToCells London-Paris res 9", a5_linestring_to_cells(london_paris, resolution = 9L))
bench_case("lineStringToCells round-the-world res 6", a5_linestring_to_cells(round_the_world, resolution = 6L))
