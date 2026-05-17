# ──────────────────────────────────────────────────────────────────────────────
# ────────── caugi_constraints — solver-backed consistent + enumerate ──────────
# ──────────────────────────────────────────────────────────────────────────────

# ── Robinson DAG counts ─────────────────────────────────────────────────────
# Number of labelled DAGs on n nodes (OEIS A003024): 1, 3, 25, 543, ...

test_that("enumerate() reproduces the Robinson DAG sequence for n = 1..3", {
  empty <- caugi_constraints()
  expect_equal(length(enumerate(empty, c("A"), limit = 10)), 1L)
  expect_equal(length(enumerate(empty, c("A", "B"), limit = 10)), 3L)
  expect_equal(length(enumerate(empty, c("A", "B", "C"), limit = 200)), 25L)
})

test_that("enumerate(n=4) matches Robinson 543 (skipped on CRAN)", {
  testthat::skip_on_cran()
  expect_equal(
    length(enumerate(caugi_constraints(), c("A", "B", "C", "D"), limit = 1000)),
    543L
  )
})

test_that("limit caps the number of returned DAGs", {
  out <- enumerate(caugi_constraints(), c("A", "B", "C"), limit = 5)
  expect_equal(length(out), 5L)
})

# ── consistent() ────────────────────────────────────────────────────────────

test_that("an empty constraint set is consistent over any node set", {
  expect_true(consistent(caugi_constraints(), c("A", "B", "C")))
})

test_that("an edge atom is consistent on a DAG", {
  expect_true(consistent(caugi_constraints(A %-->% B), c("A", "B")))
})

test_that("a 2-cycle is detected as inconsistent under DAG invariants", {
  expect_false(consistent(
    caugi_constraints(A %-->% B, B %-->% A),
    c("A", "B")
  ))
})

test_that("longer cycles are caught too", {
  expect_false(consistent(
    caugi_constraints(A %-->% B, B %-->% C, C %-->% A),
    c("A", "B", "C")
  ))
})

test_that("forbidden ancestor relation rules out the implying edge chain", {
  # !(D %in% ancestors(A)) plus D --> ... --> A should be UNSAT.
  ctr <- caugi_constraints(D %-->% B, B %-->% A, !(D %in% ancestors(A)))
  expect_false(consistent(ctr, c("A", "B", "D")))
})

test_that("topological ordering via %<<% rejects backward edges", {
  ctr <- caugi_constraints(c("A") %<<% c("B"))
  # A precedes B: B-->A would be a cycle… but here we just forbid B as
  # an ancestor of A; B-->A is the direct case.
  expect_false(consistent(ctr & caugi_constraints(B %-->% A), c("A", "B")))
  expect_true(consistent(ctr & caugi_constraints(A %-->% B), c("A", "B")))
})

# ── enumerate() with constraints ────────────────────────────────────────────

test_that("requiring an edge narrows the DAG family correctly", {
  # On 3 nodes there are 25 DAGs total; how many contain A --> B?
  # By symmetry: a DAG either includes A->B, B->A, or neither.
  # For a *fixed* directed edge A->B, we count DAGs satisfying that.
  out <- enumerate(
    caugi_constraints(A %-->% B),
    c("A", "B", "C"),
    limit = 200
  )
  # Every result must contain the edge.
  for (cg in out) {
    e <- edges(cg)
    expect_true(any(e$from == "A" & e$edge == "-->" & e$to == "B"))
  }
  expect_gt(length(out), 0L)
})

test_that("forbidden edge is absent from every enumerated DAG", {
  out <- enumerate(
    caugi_constraints(!(A %-->% B)),
    c("A", "B"),
    limit = 10
  )
  for (cg in out) {
    e <- edges(cg)
    expect_false(any(e$from == "A" & e$to == "B"))
  }
})

test_that("each enumerated DAG actually satisfies the constraints (round-trip)", {
  ctr <- caugi_constraints(A %-->% B, c("A") %<<% c("B"))
  out <- enumerate(ctr, c("A", "B", "C"), limit = 50)
  for (cg in out) {
    expect_true(satisfies(cg, ctr))
  }
})

# ── cardinality ─────────────────────────────────────────────────────────────

test_that("bounded in-degree via cardinality is enforced", {
  ctr <- caugi_constraints(forall(X, at_most(1, parents(X))))
  out <- enumerate(ctr, c("A", "B", "C"), limit = 200)
  for (cg in out) {
    e <- edges(cg)
    for (node in c("A", "B", "C")) {
      expect_lte(sum(e$to == node), 1L)
    }
  }
})

test_that("exactly(k, parents(X)) pins the in-degree", {
  ctr <- caugi_constraints(exactly(2, parents(C)))
  # Over {A, B, C}: C must have exactly 2 parents → {A->C, B->C}.
  out <- enumerate(ctr, c("A", "B", "C"), limit = 100)
  for (cg in out) {
    e <- edges(cg)
    expect_equal(sum(e$to == "C"), 2L)
  }
})

# ── input validation ────────────────────────────────────────────────────────

test_that("consistent() and enumerate() validate their inputs", {
  expect_error(consistent("not a ctr", c("A")), "caugi_constraints")
  expect_error(consistent(caugi_constraints(), character(0)), "non-empty")
  expect_error(consistent(caugi_constraints(), c("A", "A")), "unique")
  expect_error(
    enumerate(caugi_constraints(), c("A", "B"), limit = -1),
    "non-negative integer"
  )
})

test_that("encoder rejects evaluator-only atoms with a clear message", {
  expect_error(
    consistent(caugi_constraints(dsep(A, B)), c("A", "B")),
    "Tier-C|dsep"
  )
})

test_that("unknown node referenced in a constraint errors", {
  expect_error(
    consistent(caugi_constraints(A %-->% Z), c("A", "B")),
    "Unknown node"
  )
})

# ── Other graph classes ─────────────────────────────────────────────────────

test_that("UG enumeration matches 2^C(n,2)", {
  # UGs on n nodes: each of the n(n-1)/2 unordered pairs is in/out.
  expect_equal(length(enumerate(caugi_constraints(), c("A","B"),
                                class = "UG", limit = 20)), 2L^1L)
  expect_equal(length(enumerate(caugi_constraints(), c("A","B","C"),
                                class = "UG", limit = 50)), 2L^3L)
  expect_equal(length(enumerate(caugi_constraints(), c("A","B","C","D"),
                                class = "UG", limit = 200)), 2L^6L)
})

test_that("PDAG enumeration: n=3 gives 62 (4^3 - 2 directed 3-cycles)", {
  expect_equal(length(enumerate(caugi_constraints(), c("A","B","C"),
                                class = "PDAG", limit = 200)), 62L)
})

test_that("ADMG enumeration: n=3 gives 62 (mirror of PDAG)", {
  expect_equal(length(enumerate(caugi_constraints(), c("A","B","C"),
                                class = "ADMG", limit = 200)), 62L)
})

test_that("UG: required undirected edge is in every result", {
  out <- enumerate(caugi_constraints(A %---% B),
                   c("A", "B", "C"), class = "UG", limit = 50)
  expect_gt(length(out), 0L)
  for (cg in out) {
    e <- edges(cg)
    expect_true(any(e$edge == "---" &
                    ((e$from == "A" & e$to == "B") |
                     (e$from == "B" & e$to == "A"))))
  }
})

test_that("PDAG: cannot mix directed and undirected on the same pair", {
  # Mutex: requiring both A --> B and A --- B should be inconsistent.
  expect_false(consistent(
    caugi_constraints(A %-->% B, A %---% B),
    c("A", "B"),
    class = "PDAG"
  ))
})

test_that("ADMG: bidirected edge is symmetric (A <-> B == B <-> A)", {
  out <- enumerate(caugi_constraints(A %<->% B),
                   c("A", "B"), class = "ADMG", limit = 50)
  # All results must contain the bidirected edge in canonical form.
  for (cg in out) {
    e <- edges(cg)
    expect_true(any(e$edge == "<->"))
  }
})

test_that("ADMG: spouses query routes to bidirected edge", {
  expect_true(consistent(
    caugi_constraints(B %in% spouses(A)),
    c("A", "B"),
    class = "ADMG"
  ))
  # In a PDAG there are no bidirected edges, so spouses is always empty.
  expect_false(consistent(
    caugi_constraints(B %in% spouses(A)),
    c("A", "B"),
    class = "PDAG"
  ))
})

test_that("class-incompatible edge atom errors with a clear message", {
  expect_error(
    consistent(caugi_constraints(A %<->% B), c("A","B"), class = "DAG"),
    "Edge type"
  )
  expect_error(
    consistent(caugi_constraints(A %-->% B), c("A","B"), class = "UG"),
    "Edge type"
  )
})

test_that("ADMG: directed cycles still rejected but bidirected loops are fine", {
  # A --> B --> A is a directed cycle → UNSAT
  expect_false(consistent(
    caugi_constraints(A %-->% B, B %-->% A),
    c("A", "B"),
    class = "ADMG"
  ))
  # A <-> B doesn't participate in cycles → SAT
  expect_true(consistent(
    caugi_constraints(A %<->% B),
    c("A", "B"),
    class = "ADMG"
  ))
})

test_that("enumerate() returns caugi objects carrying the right class", {
  out <- enumerate(caugi_constraints(A %---% B),
                   c("A", "B"), class = "UG", limit = 5)
  for (cg in out) {
    expect_equal(cg@graph_class, "UG")
  }
  out <- enumerate(caugi_constraints(A %-->% B),
                   c("A", "B", "C"), class = "PDAG", limit = 20)
  for (cg in out) {
    expect_true(cg@graph_class %in% c("PDAG", "DAG", "MPDAG"))
  }
})

test_that("input validation: unknown class errors", {
  expect_error(
    consistent(caugi_constraints(), c("A"), class = "MAG"),
    "must be one of"
  )
})
