# nocov start
.onLoad <- function(libname, pkgname) {
  n <- getOption("a5R.threads")
  if (is.null(n)) {
    env <- Sys.getenv("A5R_NUM_THREADS", unset = "")
    if (nzchar(env)) {
      n <- as.integer(env)
    }
  }
  if (!is.null(n) && !is.na(n) && n >= 1L) {
    a5_set_threads_rs(as.integer(n))
  }
}
# nocov end
