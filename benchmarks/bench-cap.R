# Spherical caps: mirrors benches/cap.rs.
london9 <- a5_lonlat_to_cell(-0.1276, 51.5072, resolution = 9L)
london12 <- a5_lonlat_to_cell(-0.1276, 51.5072, resolution = 12L)

bench_group("sphericalCap")
bench_case("sphericalCap res 9 radius 10km", a5_spherical_cap(london9, radius = 10000))
bench_case("sphericalCap res 9 radius 100km", a5_spherical_cap(london9, radius = 100000))
bench_case("sphericalCap res 12 radius 5km", a5_spherical_cap(london12, radius = 5000))
