# ──────────────────────────────────────────────────────────────────────────────
# ───────────── caugi_constraints — evaluator: forall / exists ─────────────────
# ──────────────────────────────────────────────────────────────────────────────

.dag <- function() {
  caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )
}

# ── single-variable forall ────────────────────────────────────────────────────

test_that("forall(X, X %in% ancestors(D)) is FALSE if any node isn't an ancestor", {
  cg <- .dag()
  # D itself isn't an ancestor of D, so this fails.
  expect_false(satisfies(
    cg,
    caugi_constraints(forall(X, X %in% ancestors(D)))
  ))
})

test_that("forall(X, !(D %in% ancestors(X))) ⇔ D is a sink", {
  cg <- .dag()
  # On the test DAG, D is the only sink so for every X, D is NOT in ancestors(X).
  # Actually: D is in ancestors(X) iff X is a descendant of D, which only X=D
  # would be — but a node is not its own ancestor, so this holds for every X.
  expect_true(satisfies(
    cg,
    caugi_constraints(forall(X, !(D %in% ancestors(X))))
  ))
})

test_that("exists(X, X %-->% Y) finds at least one parent edge", {
  cg <- .dag()
  # exists X such that X --> B. A is such an X.
  expect_true(satisfies(
    cg,
    caugi_constraints(exists(X, X %-->% B))
  ))
})

test_that("exists(X, X %-->% A) is FALSE because A has no parents", {
  cg <- .dag()
  expect_false(satisfies(
    cg,
    caugi_constraints(exists(X, X %-->% A))
  ))
})

# ── multi-variable quantifiers ────────────────────────────────────────────────

test_that("forall(c(X,Y), …) enumerates ordered pairs of distinct nodes", {
  cg <- .dag()
  # For every ordered pair (X, Y) of distinct nodes, X is NOT both a parent
  # and child of Y simultaneously. (No 2-cycles in a DAG.)
  expect_true(satisfies(
    cg,
    caugi_constraints(
      forall(c(X, Y), !((X %-->% Y) & (Y %-->% X)))
    )
  ))
})

test_that("exists(c(X,Y), X %-->% Y & Y %-->% D) finds A → B → D and A → C → D", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints(
      exists(c(X, Y), (X %-->% Y) & (Y %-->% D))
    )
  ))
})

# ── empty graph ──────────────────────────────────────────────────────────────

test_that("forall on more vars than the graph has is vacuously TRUE", {
  cg <- caugi(A %-->% B, class = "DAG") # 2 nodes
  expect_true(satisfies(
    cg,
    caugi_constraints(forall(c(X, Y, Z), X %-->% Y))
  ))
})

test_that("exists on more vars than the graph has is FALSE", {
  cg <- caugi(A %-->% B, class = "DAG") # 2 nodes
  expect_false(satisfies(
    cg,
    caugi_constraints(exists(c(X, Y, Z), X %-->% Y))
  ))
})

# ── nesting and shadowing ────────────────────────────────────────────────────

test_that("nested forall composes (every X reaches D or some Y reaches D)", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints(
      forall(X, exists(Y, Y %in% ancestors(D)) | !(X %in% ancestors(D)))
    )
  ))
})

test_that("violations() pinpoints failing quantified formulas", {
  cg <- .dag()
  ctr <- caugi_constraints(
    forall(X, X %in% ancestors(D)) # fails: D isn't in ancestors(D)
  )
  v <- violations(cg, ctr)
  expect_identical(v$index, 1L)
  expect_match(v$formula, "forall", fixed = TRUE)
})
