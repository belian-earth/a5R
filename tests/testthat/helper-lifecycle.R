# Silence routine lifecycle deprecation warnings emitted by deprecated
# functions exercised by the test suite. testthat's `local_reproducible_output()`
# resets `lifecycle_verbosity` to "warning" at the start of every `test_that()`,
# so a global option set here has no effect inside tests. Use the helper below
# at the top of test bodies that call deprecated functions.
#
# Explicit deprecation tests use `lifecycle::expect_deprecated()`, which forces
# the warning regardless.
local_quiet_lifecycle <- function(.env = parent.frame()) {
  withr::local_options(lifecycle_verbosity = "quiet", .local_envir = .env)
}
