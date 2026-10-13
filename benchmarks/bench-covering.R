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

# a5R coverings: vectors of coverings, which the other ports do not have.
# Only on a5R >= 1.0, as before it the same calls returned plain cells.
if (exists("a5_union")) {
  countries <- do.call(c, lapply(
    c("France", "Brazil", "United Kingdom", "Fiji", "United States of America"),
    load_country
  ))
  countries7 <- a5_polygon_to_cells(countries, resolution = 7L)
  cap7 <- a5_spherical_cap(a5_lonlat_to_cell(2.3522, 48.8566, resolution = 7L), radius = 1500000)
  N <- 256L
  cells9 <- sample_cells(9L, N)
  disks <- a5_grid_disk(cells9, k = 2L)
  raw_disks <- unclass(disks)

  bench_group("coverings")
  bench_case("polygonToCells 5 countries res 7, per feature",
             a5_polygon_to_cells(countries, resolution = 7L), n = 5L)
  bench_case("union of 5 country coverings res 7", a5_union(countries7), n = 5L)
  bench_case("intersect 5 countries with cap res 7, recycled",
             a5_intersect(countries7, cap7), n = 5L)
  bench_case("contains 256 disks row-wise res 9", a5_contains(disks, cells9), n = N)
  bench_case("uncompact 256 disks list", a5_uncompact(disks, simplify = FALSE), n = N)
  bench_case("area 256 disks", a5_area(disks), n = N)
  bench_case("format 256 coverings", format(disks), n = N)
  bench_case("as_a5_covering 256 raw coverings", as_a5_covering(raw_disks), n = N)
}
