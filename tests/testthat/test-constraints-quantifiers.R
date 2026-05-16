# ──────────────────────────────────────────────────────────────────────────────
# ─────────── caugi_constraints — forall / exists quantifier surface ───────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("forall(X, body) records the bound variable and classified body", {
  ctr <- caugi:::caugi_constraints(forall(X, X %-->% Y))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "forall")
  expect_identical(top$vars, "X")
  expect_identical(top$scope, list(kind = "all_nodes"))
  expect_identical(
    top$body,
    list(
      kind = "atom",
      atom = list(kind = "edge", from = "X", to = "Y", etype = "-->")
    )
  )
})

test_that("exists(Z, body) records the bound variable and body", {
  ctr <- caugi:::caugi_constraints(exists(Z, Z %-->% Y))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "exists")
  expect_identical(top$vars, "Z")
  expect_identical(top$body$atom$kind, "edge")
})

test_that("multi-variable quantifiers accept c(X, Y, ...)", {
  ctr <- caugi:::caugi_constraints(
    forall(c(X, Y, Z), (X %-->% Y) & (Y %-->% Z))
  )
  top <- ctr@formulas[[1]]
  expect_identical(top$vars, c("X", "Y", "Z"))
  expect_identical(top$body$kind, "and")
})

test_that("quantifier body composes with the full constraint surface", {
  ctr <- caugi:::caugi_constraints(
    forall(X, X %in% parents(Y) | X %in% spouses(Y)),
    exists(Z, Z %in% ancestors(X) & Z %in% ancestors(Y))
  )
  expect_identical(ctr@formulas[[1]]$body$kind, "or")
  expect_identical(
    ctr@formulas[[1]]$body$args[[1]]$atom$query,
    "parents"
  )
  expect_identical(ctr@formulas[[2]]$kind, "exists")
  expect_identical(ctr@formulas[[2]]$body$kind, "and")
})

test_that("nested quantifiers nest cleanly", {
  ctr <- caugi:::caugi_constraints(
    forall(X, forall(Y, X %-->% Y))
  )
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "forall")
  expect_identical(top$body$kind, "forall")
  expect_identical(top$body$vars, "Y")
})

# ── argument shape errors ─────────────────────────────────────────────────────

test_that("wrong arity errors", {
  expect_error(
    caugi:::caugi_constraints(forall(X)),
    "expects exactly 2 argument"
  )
  expect_error(
    caugi:::caugi_constraints(forall(X, X %-->% Y, extra)),
    "expects exactly 2 argument"
  )
})

test_that("non-symbol bound variables error", {
  expect_error(
    caugi:::caugi_constraints(forall("X", X %-->% Y)),
    "bare symbol"
  )
  expect_error(
    caugi:::caugi_constraints(forall(c(X, "Y"), X %-->% Y)),
    "bare symbols"
  )
})

test_that("duplicate bound variables error", {
  expect_error(
    caugi:::caugi_constraints(forall(c(X, X), X %-->% Y)),
    "must be unique"
  )
})

test_that("malformed body inside a quantifier surfaces the inner error", {
  expect_error(
    caugi:::caugi_constraints(forall(X, some_unknown_fn(X))),
    "extras/design/constraints-plan.md"
  )
})

# ── outside-constraint stubs ──────────────────────────────────────────────────

test_that("forall called at top level errors with a pointer", {
  expect_error(caugi:::forall("X", NULL), "only meaningful inside")
})

test_that("exists at top level falls through to base::exists, not a caugi stub", {
  # We intentionally don't shadow base::exists. A user typing
  # `exists(...)` outside `caugi_constraints` gets the well-known base
  # function; the constraint form is recognised only inside the
  # constructor's NSE capture.
  expect_true(exists("test_that"))
})
