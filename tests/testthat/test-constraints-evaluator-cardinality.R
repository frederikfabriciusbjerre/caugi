# ──────────────────────────────────────────────────────────────────────────────
# ───────────── caugi_constraints — evaluator: cardinality forms ───────────────
# ──────────────────────────────────────────────────────────────────────────────

.dag <- function() {
  caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )
}

# ── formula-set cardinality ──────────────────────────────────────────────────

test_that("at_most counts how many listed formulas hold", {
  cg <- .dag()
  # Two of these three edges exist (A->B, B->D); B->A doesn't.
  expect_true(satisfies(
    cg,
    caugi_constraints(at_most(2, c(A %-->% B, B %-->% D, B %-->% A)))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints(at_most(1, c(A %-->% B, B %-->% D, B %-->% A)))
  ))
})

test_that("at_least and exactly work for formula sets", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints(at_least(2, c(A %-->% B, B %-->% D, B %-->% A)))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints(at_least(3, c(A %-->% B, B %-->% D, B %-->% A)))
  ))
  expect_true(satisfies(
    cg,
    caugi_constraints(exactly(2, c(A %-->% B, B %-->% D, B %-->% A)))
  ))
})

# ── query-set cardinality ────────────────────────────────────────────────────

test_that("at_most counts the size of a query result", {
  cg <- .dag()
  # D has two parents (B, C).
  expect_true(satisfies(cg, caugi_constraints(at_most(2, parents(D)))))
  expect_false(satisfies(cg, caugi_constraints(at_most(1, parents(D)))))
  expect_true(satisfies(cg, caugi_constraints(exactly(2, parents(D)))))
})

test_that("ancestor-count cardinality works for tier-B queries", {
  cg <- .dag()
  # D has three ancestors: A, B, C.
  expect_true(satisfies(cg, caugi_constraints(exactly(3, ancestors(D)))))
})

# ── cardinality under quantifiers ────────────────────────────────────────────

test_that("forall + at_most(k, parents(X)) checks bounded in-degree", {
  cg <- .dag()
  # Max in-degree is 2 (D has parents B, C).
  expect_true(satisfies(
    cg,
    caugi_constraints(forall(X, at_most(2, parents(X))))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints(forall(X, at_most(1, parents(X))))
  ))
})

test_that("exists + cardinality finds a node with the right degree", {
  cg <- .dag()
  # A has 0 parents.
  expect_true(satisfies(
    cg,
    caugi_constraints(exists(X, exactly(0, parents(X))))
  ))
})

# ── edge cases ───────────────────────────────────────────────────────────────

test_that("at_most(0, c(...)) means no listed formula may hold", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints(at_most(0, c(B %-->% A, D %-->% A)))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints(at_most(0, c(A %-->% B, D %-->% A)))
  ))
})
