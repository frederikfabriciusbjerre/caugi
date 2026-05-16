# ──────────────────────────────────────────────────────────────────────────────
# ────────── caugi_constraints — xor / implies / cardinality surface ───────────
# ──────────────────────────────────────────────────────────────────────────────

# ── xor ───────────────────────────────────────────────────────────────────────

test_that("xor(p, q) classifies into a 'xor' node with two args", {
  ctr <- caugi:::caugi_constraints(xor(A %-->% B, B %-->% A))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "xor")
  expect_length(top$args, 2L)
  expect_identical(top$args[[1]]$atom$kind, "edge")
  expect_identical(top$args[[2]]$atom$from, "B")
})

test_that("xor with wrong arity errors", {
  expect_error(
    caugi:::caugi_constraints(xor(A %-->% B)),
    "expects exactly 2 argument"
  )
  expect_error(
    caugi:::caugi_constraints(xor(A %-->% B, B %-->% A, C %-->% D)),
    "expects exactly 2 argument"
  )
})

# ── implies ───────────────────────────────────────────────────────────────────

test_that("implies(p, q) records antecedent and consequent", {
  ctr <- caugi:::caugi_constraints(
    implies(A %in% ancestors(Y), !(Y %-->% A))
  )
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "implies")
  expect_identical(top$antecedent$atom$kind, "membership")
  expect_identical(top$consequent$kind, "not")
})

test_that("implies with wrong arity errors", {
  expect_error(
    caugi:::caugi_constraints(implies(A %-->% B)),
    "expects exactly 2 argument"
  )
})

test_that("`implies()` outside a constraint errors with a pointer", {
  expect_error(caugi:::implies(TRUE, FALSE), "only meaningful inside")
})

# ── cardinality: formulas form ────────────────────────────────────────────────

test_that("at_most(k, c(f1, f2, ...)) classifies a formula-set cardinality", {
  ctr <- caugi:::caugi_constraints(
    at_most(2, c(A %-->% Y, B %-->% Y, C %-->% Y))
  )
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "cardinality")
  expect_identical(top$card_kind, "at_most")
  expect_identical(top$k, 2L)
  expect_identical(top$set$kind, "formulas")
  expect_length(top$set$formulas, 3L)
  expect_identical(top$set$formulas[[1]]$atom$kind, "edge")
})

test_that("at_least and exactly route to the same node with their own kind", {
  ctr <- caugi:::caugi_constraints(
    at_least(1, c(A %-->% Y, B %-->% Y)),
    exactly(0, c(A %-->% Y))
  )
  expect_identical(ctr@formulas[[1]]$card_kind, "at_least")
  expect_identical(ctr@formulas[[2]]$card_kind, "exactly")
  expect_identical(ctr@formulas[[2]]$k, 0L)
})

# ── cardinality: query form ───────────────────────────────────────────────────

test_that("at_most(k, query(args)) records the query and its tier", {
  ctr <- caugi:::caugi_constraints(at_most(3, parents(Y)))
  set <- ctr@formulas[[1]]$set
  expect_identical(set$kind, "query")
  expect_identical(set$query, "parents")
  expect_identical(set$tier, "A")
  expect_identical(set$args, list("Y"))
})

test_that("query-form cardinality respects the whitelist", {
  expect_error(
    caugi:::caugi_constraints(at_most(3, not_a_query(Y))),
    "must be `c\\(...\\)`"
  )
})

# ── cardinality: argument shape errors ────────────────────────────────────────

test_that("non-integer k errors", {
  expect_error(
    caugi:::caugi_constraints(at_most(1.5, c(A %-->% Y))),
    "non-negative integer literal"
  )
  expect_error(
    caugi:::caugi_constraints(at_most(-1, c(A %-->% Y))),
    "non-negative integer literal"
  )
})

test_that("empty c() set errors", {
  expect_error(
    caugi:::caugi_constraints(at_most(0, c())),
    "at least one expression"
  )
})

test_that("cardinality with wrong arity errors", {
  expect_error(
    caugi:::caugi_constraints(at_most(3)),
    "expects exactly 2 argument"
  )
})

# ── outside-constraint stubs ──────────────────────────────────────────────────

test_that("cardinality stubs error when called at top level", {
  expect_error(caugi:::at_most(1, NULL), "only meaningful inside")
  expect_error(caugi:::at_least(1, NULL), "only meaningful inside")
  expect_error(caugi:::exactly(1, NULL), "only meaningful inside")
})

test_that("xor at top level falls through to base::xor", {
  # As with `exists`, we don't stub `xor` — base::xor stays accessible.
  expect_true(xor(TRUE, FALSE))
})

# ── composition ───────────────────────────────────────────────────────────────

test_that("cardinality composes inside a quantifier", {
  ctr <- caugi:::caugi_constraints(
    forall(X, at_most(3, parents(X)))
  )
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "forall")
  expect_identical(top$body$kind, "cardinality")
  expect_identical(top$body$set$kind, "query")
  expect_identical(top$body$set$args, list("X"))
})
