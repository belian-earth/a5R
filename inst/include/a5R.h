// C API of the a5R package.
//
// Use from a package that has `LinkingTo: a5R` and `Imports: a5R`. The
// functions are looked up with R_GetCCallable(), so a5R's namespace must be
// loaded first (importing anything from a5R does this).
//
// Ids are 64-bit A5 cell ids. NA cells are flagged in an int array (R
// logical layout) rather than encoded in the id.

#ifndef A5R_H
#define A5R_H

#include <stdint.h>
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

// Version of this API. Check it before use; it increases when a function's
// behaviour changes.
static inline int a5R_api_version(void) {
  static int (*fun)(void) = NULL;
  if (fun == NULL) fun = (int (*)(void)) R_GetCCallable("a5R", "a5R_api_version");
  return fun();
}

// Build an a5_cell vector of length n from ids. `is_na` may be NULL;
// otherwise element i is NA where is_na[i] is nonzero. The result is not
// protected.
static inline SEXP a5R_cells_from_u64(const uint64_t *ids, const int *is_na, R_xlen_t n) {
  static SEXP (*fun)(const uint64_t *, const int *, R_xlen_t) = NULL;
  if (fun == NULL) {
    fun = (SEXP (*)(const uint64_t *, const int *, R_xlen_t)) R_GetCCallable("a5R", "a5R_cells_from_u64");
  }
  return fun(ids, is_na, n);
}

// Read the ids of an a5_cell vector into `ids` (0 where NA) and, if not
// NULL, NA flags into `is_na`. Both must have room for the vector's length,
// which is returned; pass NULL for both to get the length only. Errors if
// `cells` is not an a5_cell vector.
static inline R_xlen_t a5R_cells_to_u64(SEXP cells, uint64_t *ids, int *is_na) {
  static R_xlen_t (*fun)(SEXP, uint64_t *, int *) = NULL;
  if (fun == NULL) {
    fun = (R_xlen_t (*)(SEXP, uint64_t *, int *)) R_GetCCallable("a5R", "a5R_cells_to_u64");
  }
  return fun(cells, ids, is_na);
}

#endif
