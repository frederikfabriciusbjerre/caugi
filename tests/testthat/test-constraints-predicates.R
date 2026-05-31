# ──────────────────────────────────────────────────────────────────────────────
# ───── caugi_constraints — standalone predicate atoms (acyclic, dsep, …) ──────
# ──────────────────────────────────────────────────────────────────────────────

test_that("acyclic() classifies to a tier-B atom", {
  ctr <- caugi:::caugi_constraints(acyclic())
  expect_identical(
    ctr@formulas[[1]]$atom,
    list(kind = "acyclic", tier = "B")
  )
})

test_that("collider(A, B, C) records the triple positionally", {
  ctr <- caugi:::caugi_constraints(collider(A, B, C))
  expect_identical(
    ctr@formulas[[1]]$atom,
    list(kind = "collider", a = "A", mid = "B", c = "C", tier = "A")
  )
})

test_that("v_structure(A, B, C) records the triple positionally", {
  ctr <- caugi:::caugi_constraints(v_structure(A, B, C))
  expect_identical(
    ctr@formulas[[1]]$atom,
    list(kind = "v_structure", a = "A", mid = "B", c = "C", tier = "A")
  )
})

# ── dsep ──────────────────────────────────────────────────────────────────────

test_that("dsep(X, Y) defaults to an empty conditioning set", {
  ctr <- caugi:::caugi_constraints(dsep(X, Y))
  atom <- ctr@formulas[[1]]$atom
  expect_identical(atom$kind, "dsep")
  expect_identical(atom$x, "X")
  expect_identical(atom$y, "Y")
  expect_identical(atom$given, character(0L))
  expect_identical(atom$tier, "C")
})

test_that("dsep(X, Y, Z) carries the conditioning set", {
  ctr <- caugi:::caugi_constraints(dsep(X, Y, Z))
  expect_identical(ctr@formulas[[1]]$atom$given, "Z")
})

test_that("dsep accepts c(...) sets in any slot", {
  ctr <- caugi:::caugi_constraints(dsep(c(X1, X2), Y, c(Z1, Z2)))
  atom <- ctr@formulas[[1]]$atom
  expect_identical(atom$x, c("X1", "X2"))
  expect_identical(atom$y, "Y")
  expect_identical(atom$given, c("Z1", "Z2"))
})

test_that("dsep accepts a named `given =` third argument by position", {
  # `as.list(expr)` preserves names but our classifier reads by index, so
  # the named arg shows up at the same position as the positional form.
  ctr <- caugi:::caugi_constraints(dsep(X, Y, given = Z))
  expect_identical(ctr@formulas[[1]]$atom$given, "Z")
})

# ── arity / shape errors ──────────────────────────────────────────────────────

test_that("wrong arity errors with the expected message", {
  expect_error(caugi:::caugi_constraints(acyclic(X)), "expects 0 argument")
  expect_error(caugi:::caugi_constraints(collider(A, B)), "expects 3 argument")
  expect_error(caugi:::caugi_constraints(dsep(X)), "expects 2 or 3 argument")
  expect_error(
    caugi:::caugi_constraints(dsep(X, Y, Z, W)),
    "expects 2 or 3 argument"
  )
})

test_that("unrecognised predicates still error with the design-doc pointer", {
  expect_error(
    caugi:::caugi_constraints(not_a_predicate(X)),
    "extras/design/constraints-plan.md"
  )
})

# ── predicates compose with the rest of the surface ───────────────────────────

test_that("predicate atoms can be negated, anded, and ored", {
  ctr <- caugi:::caugi_constraints(
    acyclic() & !v_structure(A, B, C),
    collider(A, B, C) | v_structure(A, B, C)
  )
  expect_identical(ctr@formulas[[1]]$kind, "and")
  expect_identical(ctr@formulas[[1]]$args[[2]]$kind, "not")
  expect_identical(ctr@formulas[[1]]$args[[2]]$body$atom$kind, "v_structure")
  expect_identical(ctr@formulas[[2]]$kind, "or")
})

# ── outside-constraint stubs ──────────────────────────────────────────────────

test_that("predicate stubs error helpfully when called at top level", {
  expect_error(caugi:::acyclic(), "only meaningful inside")
  expect_error(caugi:::collider("A", "B", "C"), "only meaningful inside")
  expect_error(caugi:::v_structure("A", "B", "C"), "only meaningful inside")
  expect_error(caugi:::dsep("A", "B"), "only meaningful inside")
})
