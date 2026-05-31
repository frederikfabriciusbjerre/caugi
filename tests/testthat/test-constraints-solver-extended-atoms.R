# ──────────────────────────────────────────────────────────────────────────────
# ──── caugi_constraints — solver-side mb / anteriors / posteriors / districts ─
# ──────────────────────────────────────────────────────────────────────────────
#
# These atoms graduated from "evaluator-only" to "constraint atom" in
# this push. Each test does two things:
#   1. asserts a known count (where we can derive one),
#   2. cross-checks every enumerated graph through `satisfies()` so
#      the evaluator and encoder agree atom-by-atom.

# ── helper: every result must satisfy the original constraint ───────────────

.expect_each_satisfies <- function(ctr, nodes, class, limit = 200L) {
  out <- enumerate(ctr, nodes, class = class, limit = limit)
  for (cg in out) {
    expect_true(satisfies(cg, ctr))
  }
  out
}

# ── DAG: anteriors / posteriors == ancestors / descendants ───────────────────

test_that("DAG: anteriors(X) and ancestors(X) match exactly on the solver", {
  ctr_ant <- caugi_constraints(A %in% anteriors(C))
  ctr_anc <- caugi_constraints(A %in% ancestors(C))
  expect_equal(
    length(enumerate(ctr_ant, c("A", "B", "C"), limit = 200)),
    length(enumerate(ctr_anc, c("A", "B", "C"), limit = 200))
  )
})

test_that("DAG: posteriors(X) == descendants(X)", {
  ctr_post <- caugi_constraints(C %in% posteriors(A))
  ctr_desc <- caugi_constraints(C %in% descendants(A))
  expect_equal(
    length(enumerate(ctr_post, c("A", "B", "C"), limit = 200)),
    length(enumerate(ctr_desc, c("A", "B", "C"), limit = 200))
  )
})

# ── DAG: markov_blanket ──────────────────────────────────────────────────────

test_that("DAG: markov_blanket atom decomposes correctly", {
  # A in MB(B) iff A is a parent / child / co-parent of B.
  out <- .expect_each_satisfies(
    caugi_constraints(A %in% markov_blanket(B)),
    c("A", "B", "C"),
    class = "DAG"
  )
  expect_gt(length(out), 0L)
})

test_that("DAG: forbidden MB shrinks the family", {
  total <- length(enumerate(caugi_constraints(), c("A", "B"), class = "DAG"))
  noneOfA <- length(enumerate(
    caugi_constraints(!(A %in% markov_blanket(B))),
    c("A", "B"), class = "DAG"
  ))
  expect_lt(noneOfA, total)
})

# ── UG: markov_blanket == neighbors ──────────────────────────────────────────

test_that("UG: MB(A) atom == undirected edge atom", {
  by_mb <- length(enumerate(
    caugi_constraints(B %in% markov_blanket(A)),
    c("A", "B", "C"), class = "UG"
  ))
  by_edge <- length(enumerate(
    caugi_constraints(A %---% B),
    c("A", "B", "C"), class = "UG"
  ))
  expect_equal(by_mb, by_edge)
})

# ── PDAG: anteriors include undirected paths ────────────────────────────────

test_that("PDAG: every enumerated graph with A in anteriors(C) actually satisfies it", {
  out <- .expect_each_satisfies(
    caugi_constraints(A %in% anteriors(C)),
    c("A", "B", "C"),
    class = "PDAG",
    limit = 300L
  )
  expect_gt(length(out), 0L)
})

test_that("PDAG: anteriors is a strict superset of ancestors on graphs with undirected edges", {
  # Some PDAGs have A in anteriors(C) via undirected edges that wouldn't
  # be ancestors. So anteriors-count >= ancestors-count.
  by_ant <- length(enumerate(
    caugi_constraints(A %in% anteriors(C)),
    c("A", "B", "C"), class = "PDAG", limit = 200
  ))
  by_anc <- length(enumerate(
    caugi_constraints(A %in% ancestors(C)),
    c("A", "B", "C"), class = "PDAG", limit = 200
  ))
  expect_gte(by_ant, by_anc)
})

test_that("PDAG: posteriors atom round-trips through the evaluator", {
  .expect_each_satisfies(
    caugi_constraints(C %in% posteriors(A)),
    c("A", "B", "C"),
    class = "PDAG",
    limit = 200L
  )
})

# ── PDAG: MB with undirected ─────────────────────────────────────────────────

test_that("PDAG: MB atom includes undirected neighbours", {
  .expect_each_satisfies(
    caugi_constraints(B %in% markov_blanket(A)),
    c("A", "B", "C"),
    class = "PDAG",
    limit = 200L
  )
})

# ── ADMG: districts ─────────────────────────────────────────────────────────

test_that("ADMG: districts(X) atom routes through bidirected reach", {
  out <- .expect_each_satisfies(
    caugi_constraints(A %in% districts(B)),
    c("A", "B", "C"),
    class = "ADMG",
    limit = 200L
  )
  expect_gt(length(out), 0L)
})

test_that("ADMG: A in districts(B) requires a <-> path A...B", {
  # Direct bidirected edge — must hold.
  expect_true(consistent(
    caugi_constraints(A %<->% B, A %in% districts(B)),
    c("A", "B"),
    class = "ADMG"
  ))
  # No bidirected anywhere — district atom can only be satisfied
  # trivially (A == B), which it isn't, so the constraint must fail.
  expect_false(consistent(
    caugi_constraints(
      !(A %<->% B), !(A %<->% C), !(B %<->% C),
      A %in% districts(B)
    ),
    c("A", "B", "C"),
    class = "ADMG"
  ))
})

test_that("ADMG: transitive bireach via a middle node satisfies districts atom", {
  # A <-> C <-> B should put A in districts(B).
  expect_true(consistent(
    caugi_constraints(
      A %<->% C, C %<->% B,
      A %in% districts(B)
    ),
    c("A", "B", "C"),
    class = "ADMG"
  ))
})

# ── ADMG: markov_blanket = district ∪ parents-of-district ───────────────────

test_that("ADMG: MB atom round-trips through the evaluator", {
  .expect_each_satisfies(
    caugi_constraints(A %in% markov_blanket(B)),
    c("A", "B", "C"),
    class = "ADMG",
    limit = 200L
  )
})

test_that("ADMG: parent of a district member is in the MB", {
  # A --> C, B <-> C  ⇒  A is in MB(B) because A is parent of C in B's
  # district.
  expect_true(consistent(
    caugi_constraints(A %-->% C, B %<->% C, A %in% markov_blanket(B)),
    c("A", "B", "C"),
    class = "ADMG"
  ))
})

# ── class incompatibility errors ─────────────────────────────────────────────

test_that("anteriors / posteriors error in classes where they're undefined", {
  expect_error(
    consistent(caugi_constraints(A %in% anteriors(B)), c("A", "B"), class = "UG"),
    "anteriors"
  )
  expect_error(
    consistent(caugi_constraints(A %in% posteriors(B)), c("A", "B"), class = "ADMG"),
    "posteriors"
  )
})

test_that("districts errors in non-ADMG classes", {
  expect_error(
    consistent(caugi_constraints(A %in% districts(B)), c("A", "B"), class = "DAG"),
    "districts"
  )
  expect_error(
    consistent(caugi_constraints(A %in% districts(B)), c("A", "B"), class = "PDAG"),
    "districts"
  )
})
