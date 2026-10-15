// C API for packages that build or read a5_cell vectors from compiled code.
// Registered with R_RegisterCCallable() in R_init_a5R(); see inst/include/a5R.h.
//
// An a5_cell vector is a vctrs record of eight raw vectors b1..b8 holding the
// little-endian bytes of each 64-bit id, with b8 stored XOR 0xFC so that eight
// zero bytes (the vctrs fill value) mean NA. Callers should use these
// functions rather than rely on that layout.

#include <stdint.h>
#include <R.h>
#include <Rinternals.h>

#define A5R_API_VERSION 1
#define B8_MASK 0xFC
#define NA_SENTINEL UINT64_C(0xFC00000000000000)

static int a5R_api_version(void) {
  return A5R_API_VERSION;
}

static SEXP a5R_cells_from_u64(const uint64_t *ids, const int *is_na, R_xlen_t n) {
  static const char *names[] = {"b1", "b2", "b3", "b4", "b5", "b6", "b7", "b8", ""};
  SEXP out = PROTECT(mkNamed(VECSXP, names));
  Rbyte *b[8];
  for (int j = 0; j < 8; j++) {
    SEXP field = allocVector(RAWSXP, n);
    SET_VECTOR_ELT(out, j, field);
    b[j] = RAW(field);
  }
  for (R_xlen_t i = 0; i < n; i++) {
    uint64_t id = (is_na != NULL && is_na[i]) ? NA_SENTINEL : ids[i];
    for (int j = 0; j < 8; j++) {
      b[j][i] = (Rbyte) (id >> (8 * j));
    }
    b[7][i] ^= B8_MASK;
  }
  SEXP cls = PROTECT(allocVector(STRSXP, 3));
  SET_STRING_ELT(cls, 0, mkChar("a5_cell"));
  SET_STRING_ELT(cls, 1, mkChar("vctrs_rcrd"));
  SET_STRING_ELT(cls, 2, mkChar("vctrs_vctr"));
  setAttrib(out, R_ClassSymbol, cls);
  UNPROTECT(2);
  return out;
}

static R_xlen_t a5R_cells_to_u64(SEXP cells, uint64_t *ids, int *is_na) {
  if (!inherits(cells, "a5_cell") || TYPEOF(cells) != VECSXP || XLENGTH(cells) != 8) {
    error("`cells` must be an a5_cell vector.");
  }
  const Rbyte *b[8];
  R_xlen_t n = XLENGTH(VECTOR_ELT(cells, 0));
  for (int j = 0; j < 8; j++) {
    SEXP field = VECTOR_ELT(cells, j);
    if (TYPEOF(field) != RAWSXP || XLENGTH(field) != n) {
      error("`cells` is a malformed a5_cell vector.");
    }
    b[j] = RAW(field);
  }
  for (R_xlen_t i = 0; i < n; i++) {
    uint64_t id = 0;
    for (int j = 0; j < 8; j++) {
      Rbyte byte = (j == 7) ? (Rbyte) (b[j][i] ^ B8_MASK) : b[j][i];
      id |= (uint64_t) byte << (8 * j);
    }
    int na = id == NA_SENTINEL;
    if (ids != NULL) ids[i] = na ? 0 : id;
    if (is_na != NULL) is_na[i] = na;
  }
  return n;
}

void a5R_register_api(void) {
  R_RegisterCCallable("a5R", "a5R_api_version", (DL_FUNC) a5R_api_version);
  R_RegisterCCallable("a5R", "a5R_cells_from_u64", (DL_FUNC) a5R_cells_from_u64);
  R_RegisterCCallable("a5R", "a5R_cells_to_u64", (DL_FUNC) a5R_cells_to_u64);
}
