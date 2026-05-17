# ──────────────────────────────────────────────────────────────────────────────
# ────────────── caugi_constraints — evaluator against real graphs ─────────────
# ──────────────────────────────────────────────────────────────────────────────

# A small DAG used across most tests: A → B → D, A → C → D.
.dag <- function() {
  caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )
}

# A PDAG: A — B, A → C, with a v-structure A → C ← Q for collider tests.
.pdag <- function() {
  caugi(
    A %---% B,
    A %-->% C,
    Q %-->% C,
    class = "PDAG"
  )
}

# ── empty / trivial ──────────────────────────────────────────────────────────

test_that("empty constraint set is vacuously satisfied", {
  cg <- .dag()
  expect_true(satisfies(cg, caugi_constraints()))
  expect_identical(nrow(violations(cg, caugi_constraints())), 0L)
})

test_that("evaluator rejects non-caugi or non-constraint inputs", {
  expect_error(satisfies("nope", caugi_constraints()), "caugi")
  expect_error(satisfies(.dag(), "nope"), "caugi_constraints")
  expect_error(violations("nope", caugi_constraints()), "caugi")
})

# ── edge atoms ───────────────────────────────────────────────────────────────

test_that("edge atom holds iff the graph has that edge", {
  cg <- .dag()
  expect_true(satisfies(cg, caugi_constraints(A %-->% B)))
  expect_false(satisfies(cg, caugi_constraints(B %-->% A)))
})

test_that("edge atom respects edge type (--> vs ---)", {
  cg <- .pdag()
  expect_true(satisfies(cg, caugi_constraints(A %---% B)))
  expect_false(satisfies(cg, caugi_constraints(A %-->% B)))
})

# ── boolean combinators ──────────────────────────────────────────────────────

test_that("! flips an edge atom's truth", {
  cg <- .dag()
  expect_true(satisfies(cg, caugi_constraints(!(B %-->% A))))
  expect_false(satisfies(cg, caugi_constraints(!(A %-->% B))))
})

test_that("& requires both branches; | requires either", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints((A %-->% B) & (C %-->% D))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints((A %-->% B) & (B %-->% A))
  ))
  expect_true(satisfies(
    cg,
    caugi_constraints((A %-->% B) | (B %-->% A))
  ))
})

test_that("xor and implies behave as expected", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints(xor(A %-->% B, B %-->% A))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints(xor(A %-->% B, C %-->% D)) # both true ⇒ xor false
  ))
  # antecedent true ⇒ implication needs consequent
  expect_true(satisfies(
    cg,
    caugi_constraints(implies(A %-->% B, C %-->% D))
  ))
  expect_false(satisfies(
    cg,
    caugi_constraints(implies(A %-->% B, B %-->% A))
  ))
  # antecedent false ⇒ implication vacuously true
  expect_true(satisfies(
    cg,
    caugi_constraints(implies(B %-->% A, B %-->% A))
  ))
})

# ── membership atoms ─────────────────────────────────────────────────────────

test_that("membership in parents/children/ancestors/descendants resolves correctly", {
  cg <- .dag()
  expect_true(satisfies(cg, caugi_constraints(A %in% parents(B))))
  expect_false(satisfies(cg, caugi_constraints(B %in% parents(A))))
  expect_true(satisfies(cg, caugi_constraints(A %in% ancestors(D))))
  expect_false(satisfies(cg, caugi_constraints(D %in% ancestors(A))))
  expect_true(satisfies(cg, caugi_constraints(D %in% descendants(A))))
})

test_that("negated membership flips correctly", {
  cg <- .dag()
  expect_true(satisfies(cg, caugi_constraints(!(D %in% ancestors(A)))))
})

# ── topological precedence ────────────────────────────────────────────────────

test_that("%<<% holds when no descendant flows back", {
  cg <- .dag()
  expect_true(satisfies(
    cg,
    caugi_constraints(c(A) %<<% c(B, C) %<<% c(D))
  ))
  # Reverse ordering must fail.
  expect_false(satisfies(
    cg,
    caugi_constraints(c(D) %<<% c(A))
  ))
})

# ── tier-B atoms ──────────────────────────────────────────────────────────────

test_that("acyclic() holds on a DAG", {
  expect_true(satisfies(.dag(), caugi_constraints(acyclic())))
})

# ── collider / v_structure ───────────────────────────────────────────────────

test_that("collider and v_structure detect the right triple", {
  cg <- .pdag()
  # A → C ← Q is a v-structure (A and Q not adjacent).
  expect_true(satisfies(cg, caugi_constraints(collider(A, C, Q))))
  expect_true(satisfies(cg, caugi_constraints(v_structure(A, C, Q))))
})

test_that("v_structure fails when shoulders are adjacent", {
  cg <- caugi(
    A %-->% B,
    C %-->% B,
    A %-->% C,
    class = "DAG"
  )
  expect_true(satisfies(cg, caugi_constraints(collider(A, B, C))))
  expect_false(satisfies(cg, caugi_constraints(v_structure(A, B, C))))
})

# ── dsep ──────────────────────────────────────────────────────────────────────

test_that("dsep matches d_separated()", {
  cg <- .dag()
  # A and D are d-connected through B (or C). Conditioning on B,C blocks.
  expect_false(satisfies(cg, caugi_constraints(dsep(A, D))))
  expect_true(satisfies(cg, caugi_constraints(dsep(A, D, c(B, C)))))
})

# ── violations() report ───────────────────────────────────────────────────────

test_that("violations() lists failing formulas with their index and rendering", {
  cg <- .dag()
  ctr <- caugi_constraints(
    A %-->% B, # holds
    B %-->% A, # fails
    !(D %in% ancestors(A)) # holds
  )
  v <- violations(cg, ctr)
  expect_identical(v$index, 2L)
  expect_match(v$formula, "B %-->% A", fixed = TRUE)
})

test_that("violations() is empty when the constraints all hold", {
  cg <- .dag()
  expect_identical(
    nrow(violations(cg, caugi_constraints(A %-->% B))),
    0L
  )
})

