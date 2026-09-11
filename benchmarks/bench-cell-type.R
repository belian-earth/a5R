# The a5_cell vector type: vctrs methods and base R compatibility. Not in the
# other ports; guards the record representation, the comparison and equality
# proxies, and the mtfrm / assignment methods in R/cell-base.R.
N <- 100000L
cells <- sample_cells(12L, N)
shuffled <- vctrs::vec_slice(cells, rev(seq_len(N)))
hex <- as.character(cells)
half <- vctrs::vec_slice(cells, seq_len(N / 2))

bench_group("cell-type")
bench_case("match 100k", match(cells, shuffled), n = N)
bench_case("%in% 100k", cells %in% shuffled, n = N)
bench_case("unique 100k (half duplicated)", unique(c(half, half)), n = N)
bench_case("sort 100k", sort(cells), n = N)
bench_case("order 100k", order(cells), n = N)
bench_case("== 100k", cells == shuffled, n = N)
bench_case("c two 50k", c(half, half), n = N)
bench_case("subset 100k by index", cells[seq(1L, N, 2L)], n = N)
bench_case("is.na 100k", is.na(cells), n = N)
bench_case("as.character 100k", as.character(cells), n = N)
bench_case("a5_cell from hex 100k", a5_cell(hex), n = N)
bench_case("grow by one", { z <- half; z[length(z) + 1L] <- cells[1L] }, n = N / 2)
bench_case("list_of from 256 children", a5_cell_to_children(sample_cells(10L, 256L), 12L, simplify = FALSE), n = 256L)
