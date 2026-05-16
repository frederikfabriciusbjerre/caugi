# ──────────────────────────────────────────────────────────────────────────────
# ─────────────── caugi_constraints skeleton — construction ────────────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# These tests guard the *shape* of the skeleton constructor. They will be
# tightened as parsing, classification, and evaluation land.

test_that("caugi_constraints() returns a caugi_constraints S7 object", {
  ctr <- caugi:::caugi_constraints()
  expect_true(S7::S7_inherits(ctr, caugi:::caugi_constraints_class))
})

test_that("caugi_constraints() captures expressions verbatim", {
  ctr <- caugi:::caugi_constraints(A %-->% B, !(D %-->% A))
  exprs <- ctr@expressions
  expect_type(exprs, "list")
  expect_length(exprs, 2L)
  # Captured unevaluated — should still be language objects, not values.
  expect_true(is.language(exprs[[1]]))
  expect_true(is.language(exprs[[2]]))
})

test_that("caugi_constraints() with no arguments yields an empty constraint set", {
  ctr <- caugi:::caugi_constraints()
  expect_length(ctr@expressions, 0L)
})

test_that("schema_version is fixed at 1 for the v1 AST", {
  ctr <- caugi:::caugi_constraints()
  expect_identical(ctr@schema_version, 1L)
})
