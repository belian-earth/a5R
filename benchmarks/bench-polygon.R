# Regions: mirrors benches/polygon.rs. Country outlines cover many vertices,
# large interiors, high latitudes and the antimeridian (Fiji).
cases <- list(
  list("United Kingdom", 7L),
  list("France", 7L),
  list("Brazil", 6L),
  list("United States of America", 5L),
  list("Fiji", 8L)
)

bench_group("polygonToCells")
for (case in cases) {
  polygon <- load_country(case[[1]])
  bench_case(sprintf("polygonToCells %s res %d", case[[1]], case[[2]]),
             a5_polygon_to_cells(polygon, resolution = case[[2]]))
}
uk <- load_country("United Kingdom")
bench_case("polygonToCells United Kingdom res 7 overlapping",
           a5_polygon_to_cells(uk, resolution = 7L, containment = "overlapping"))
