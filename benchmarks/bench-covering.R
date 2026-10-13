# Covering set operations: mirrors benches/covering.rs. Coverings at
# resolution 12: two neighbouring countries and a cap overlapping both.
france <- a5_polygon_to_cells(load_country("France"), resolution = 12L)
uk <- a5_polygon_to_cells(load_country("United Kingdom"), resolution = 12L)
paris <- a5_lonlat_to_cell(2.3522, 48.8566, resolution = 12L)
cap_paris <- a5_spherical_cap(paris, radius = 400000)

# Point-in-polygon probes: cells, at the covering's resolution, of random
# points in France's bounding box.
random <- create_random(7)
probe_lon <- numeric(1000L)
probe_lat <- numeric(1000L)
for (i in seq_len(1000L)) {
  probe_lon[i] <- -5 + 13 * random()
  probe_lat[i] <- 42 + 9 * random()
}
probes <- a5_lonlat_to_cell(probe_lon, probe_lat, resolution = 12L)

# Stored values, compaction markers included, as a5-rs counts them.
stored <- sum(lengths(unclass(c(france, uk))) %/% 8L)

bench_group("set operations")
bench_case(sprintf("union France + UK res 12 (%d compacted cells)", stored),
           a5_union(france, uk))
bench_case("intersect France with Paris cap res 12", a5_intersect(france, cap_paris))
bench_case("difference France minus Paris cap res 12", a5_difference(france, cap_paris))
bench_case("count France res 12", a5_count(france))
bench_case("contains France res 12, 1000 points", a5_contains(france, probes), n = 1000L)
