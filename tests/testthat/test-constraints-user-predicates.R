# ──────────────────────────────────────────────────────────────────────────────
# ────────── caugi_constraints — user-defined predicates ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi_predicate() returns a function with the right class and attrs", {
  p <- caugi_predicate(function(X, Y) X %-->% Y)
  expect_s3_class(p, "caugi_predicate")
  expect_identical(attr(p, "caugi_predicate_params"), c("X", "Y"))
})

test_that("predicate invocation inlines its body into the constraint", {
  edge_must_exist <- caugi_predicate(function(U, V) U %-->% V)
  ctr <- caugi_constraints(edge_must_exist(A, B))
  expect_identical(
    ctr@formulas[[1]],
    list(
      kind = "atom",
      atom = list(kind = "edge", from = "A", to = "B", etype = "-->")
    )
  )
})

test_that("predicate substitution reaches every leaf in a nested body", {
  acyclic_anc <- caugi_predicate(function(X, Y) {
    forall(Z, implies(
      (Z %in% ancestors(X)) & (Z %in% ancestors(Y)),
      observed(Z)
    ))
  })
  ctr <- caugi_constraints(acyclic_anc(A, B))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "forall")
  # The X reference in `ancestors(X)` should now be `A`.
  ancestors_arg <- top$body$consequent
  # body is `implies(...)`; antecedent is the `&` of two memberships.
  ant_args <- top$body$antecedent$args
  expect_identical(ant_args[[1]]$atom$query, "ancestors")
  expect_identical(ant_args[[1]]$atom$args, list("A"))
  expect_identical(ant_args[[2]]$atom$args, list("B"))
})

test_that("predicate arity mismatch errors", {
  p <- caugi_predicate(function(X, Y) X %-->% Y)
  expect_error(
    caugi_constraints(p(A)),
    "expects 2 argument"
  )
  expect_error(
    caugi_constraints(p(A, B, C)),
    "expects 2 argument"
  )
})

test_that("calling a predicate at top level errors with a pointer", {
  p <- caugi_predicate(function(X) X %-->% Y)
  expect_error(p("A"), "only meaningful inside")
})

test_that("predicates can call other predicates (transitive substitution)", {
  edge <- caugi_predicate(function(U, V) U %-->% V)
  both_edges <- caugi_predicate(function(A1, B1, C1) edge(A1, B1) & edge(B1, C1))
  ctr <- caugi_constraints(both_edges(P, Q, R))
  expect_identical(ctr@formulas[[1]]$kind, "and")
  expect_identical(ctr@formulas[[1]]$args[[1]]$atom$from, "P")
  expect_identical(ctr@formulas[[1]]$args[[1]]$atom$to, "Q")
  expect_identical(ctr@formulas[[1]]$args[[2]]$atom$from, "Q")
  expect_identical(ctr@formulas[[1]]$args[[2]]$atom$to, "R")
})

test_that("predicate composes with the evaluator end-to-end", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  has_path <- caugi_predicate(function(X, Y) X %in% ancestors(Y))
  expect_true(satisfies(cg, caugi_constraints(has_path(A, C))))
  expect_false(satisfies(cg, caugi_constraints(has_path(C, A))))
})

test_that("caugi_predicate() rejects non-functions or zero-arg functions", {
  expect_error(caugi_predicate("not a fn"), "expects a function")
  expect_error(caugi_predicate(function() TRUE), "at least one parameter")
})
