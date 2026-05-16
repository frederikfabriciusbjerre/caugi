# ──────────────────────────────────────────────────────────────────────────────
# ──────── caugi_constraints — boolean algebra between constraint sets ─────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("& between two constraint sets concatenates their formulas", {
  ctr1 <- caugi:::caugi_constraints(A %-->% B, C %-->% D)
  ctr2 <- caugi:::caugi_constraints(E %-->% F)
  combined <- ctr1 & ctr2
  expect_true(S7::S7_inherits(combined, caugi:::caugi_constraints_class))
  expect_length(combined@formulas, 3L)
  expect_identical(combined@formulas[[1]]$atom$from, "A")
  expect_identical(combined@formulas[[3]]$atom$from, "E")
})

test_that("& is associative on the formulas list", {
  ctr1 <- caugi:::caugi_constraints(A %-->% B)
  ctr2 <- caugi:::caugi_constraints(C %-->% D)
  ctr3 <- caugi:::caugi_constraints(E %-->% F)
  left <- (ctr1 & ctr2) & ctr3
  right <- ctr1 & (ctr2 & ctr3)
  expect_identical(left@formulas, right@formulas)
})

test_that("& with an empty constraint set is a no-op", {
  ctr <- caugi:::caugi_constraints(A %-->% B)
  empty <- caugi:::caugi_constraints()
  expect_identical((ctr & empty)@formulas, ctr@formulas)
  expect_identical((empty & ctr)@formulas, ctr@formulas)
  expect_length((empty & empty)@formulas, 0L)
})

test_that("| produces a single Or-of-conjunctions formula", {
  ctr1 <- caugi:::caugi_constraints(A %-->% B, C %-->% D)
  ctr2 <- caugi:::caugi_constraints(E %-->% F)
  ored <- ctr1 | ctr2
  expect_length(ored@formulas, 1L)
  top <- ored@formulas[[1]]
  expect_identical(top$kind, "or")
  expect_length(top$args, 2L)
  expect_identical(top$args[[1]]$kind, "and")
  expect_identical(top$args[[2]]$atom$kind, "edge")
})

test_that("| collapses singleton conjunctions to the lone formula", {
  ctr1 <- caugi:::caugi_constraints(A %-->% B)
  ctr2 <- caugi:::caugi_constraints(C %-->% D)
  ored <- ctr1 | ctr2
  top <- ored@formulas[[1]]
  expect_identical(top$args[[1]]$atom$from, "A")
  expect_identical(top$args[[2]]$atom$from, "C")
})

test_that("| with an empty constraint set wraps `And([])` (vacuously true)", {
  ctr <- caugi:::caugi_constraints(A %-->% B)
  empty <- caugi:::caugi_constraints()
  ored <- ctr | empty
  top <- ored@formulas[[1]]
  expect_identical(top$kind, "or")
  expect_identical(top$args[[2]]$kind, "and")
  expect_length(top$args[[2]]$args, 0L)
})

test_that("negate() wraps the conjunction in a single Not formula", {
  ctr <- caugi:::caugi_constraints(A %-->% B, C %-->% D)
  negated <- caugi:::negate(ctr)
  expect_length(negated@formulas, 1L)
  top <- negated@formulas[[1]]
  expect_identical(top$kind, "not")
  expect_identical(top$body$kind, "and")
  expect_length(top$body$args, 2L)
})

test_that("negate() of a singleton constraint negates the lone formula directly", {
  ctr <- caugi:::caugi_constraints(A %-->% B)
  negated <- caugi:::negate(ctr)
  top <- negated@formulas[[1]]
  expect_identical(top$kind, "not")
  expect_identical(top$body$atom$kind, "edge")
})

test_that("negate() of an empty constraint set yields Not(And([]))", {
  # That's `Not(True) = False` semantically; the AST preserves the
  # explicit form for the evaluator/encoder to interpret.
  empty <- caugi:::caugi_constraints()
  negated <- caugi:::negate(empty)
  top <- negated@formulas[[1]]
  expect_identical(top$kind, "not")
  expect_identical(top$body$kind, "and")
  expect_length(top$body$args, 0L)
})

test_that("negate() composes with itself without auto-simplification", {
  # Kept syntactic; downstream passes can normalise if they need to.
  ctr <- caugi:::caugi_constraints(A %-->% B)
  twice <- caugi:::negate(caugi:::negate(ctr))
  expect_identical(twice@formulas[[1]]$kind, "not")
  expect_identical(twice@formulas[[1]]$body$kind, "not")
})

test_that("negate() rejects non-caugi_constraints inputs", {
  expect_error(caugi:::negate("not a constraint"), "expects a `caugi_constraints` object")
})
