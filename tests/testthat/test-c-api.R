test_that("the C API round-trips ids and NA through a5_cell", {
  # covr runs without NOT_CRAN; the test must run there to cover src/api.c
  if (!identical(Sys.getenv("R_COVR"), "true")) skip_on_cran()
  inc <- system.file("include", package = "a5R")
  skip_if(!nzchar(inc) || !file.exists(file.path(inc, "a5R.h")))
  dir <- withr::local_tempdir()
  src <- file.path(dir, "client.c")
  writeLines(c(
    '#include <a5R.h>',
    'SEXP client_version(void) { return ScalarInteger(a5R_api_version()); }',
    'SEXP client_roundtrip(SEXP cells) {',
    '  R_xlen_t n = a5R_cells_to_u64(cells, NULL, NULL);',
    '  uint64_t *ids = (uint64_t *) R_alloc(n, sizeof(uint64_t));',
    '  int *na = (int *) R_alloc(n, sizeof(int));',
    '  a5R_cells_to_u64(cells, ids, na);',
    '  return a5R_cells_from_u64(ids, na, n);',
    '}',
    'SEXP client_from_ids(void) {',
    '  uint64_t ids[2] = {UINT64_C(0x0800000000000006), UINT64_C(0xfc00000000000001)};',
    '  return a5R_cells_from_u64(ids, NULL, 2);',
    '}'
  ), src)
  withr::local_envvar(PKG_CPPFLAGS = paste0("-I", inc))
  out <- system2(
    file.path(R.home("bin"), "R"), c("CMD", "SHLIB", shQuote(src)),
    stdout = TRUE, stderr = TRUE
  )
  so <- sub("\\.c$", .Platform$dynlib.ext, src)
  skip_if(!file.exists(so), paste(out, collapse = "\n"))
  dll <- dyn.load(so)
  withr::defer(dyn.unload(so))

  expect_identical(.Call("client_version", PACKAGE = "client"), 1L)
  cells <- a5_cell(c("0800000000000006", NA, "fc00000000000001"))
  back <- .Call("client_roundtrip", cells, PACKAGE = "client")
  expect_identical(back, cells)
  expect_identical(
    format(.Call("client_from_ids", PACKAGE = "client")),
    c("0800000000000006", "fc00000000000001")
  )
  expect_error(.Call("client_roundtrip", 1:3, PACKAGE = "client"), "a5_cell")
  broken <- unclass(cells)
  broken$b3 <- 1:3
  class(broken) <- class(cells)
  expect_error(.Call("client_roundtrip", broken, PACKAGE = "client"), "malformed")
})
