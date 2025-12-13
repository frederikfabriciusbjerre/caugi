# Tests for ADMG (Acyclic Directed Mixed Graph) functionality

# ─────────────────────────────────────────────────────────────────────────────
# ADMG Construction and Validation
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_admg correctly identifies ADMG graphs", {
  # Pure DAG is also a valid ADMG
  dag <- caugi(A %-->% B %-->% C, class = "DAG")
  expect_true(is_admg(dag, force_check = TRUE))

  # ADMG with bidirected edges
  admg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )
  expect_true(is_admg(admg))
  expect_equal(admg@graph_class, "ADMG")
})

test_that("ADMG rejects undirected edges", {
  expect_error(
    caugi(
      A %-->% B,
      B %---% C,
      class = "ADMG"
    ),
    regexp = "directed and bidirected"
  )
})

test_that("ADMG rejects directed cycles", {
  expect_error(
    caugi(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "ADMG"
    ),
    regexp = "cycle"
  )
})

# ─────────────────────────────────────────────────────────────────────────────
# Spouses Query
# ─────────────────────────────────────────────────────────────────────────────

test_that("spouses returns bidirected neighbors", {
  admg <- caugi(
    A %-->% B,
    A %<->% C,
    B %<->% C,
    class = "ADMG"
  )

  # A is spouse of C via A <-> C

  expect_equal(spouses(admg, "A"), "C")

  # C is spouse of both A and B
  sp_c <- spouses(admg, "C")
  expect_true(all(c("A", "B") %in% sp_c))

  # B has no parents but has spouse C
  expect_equal(spouses(admg, "B"), "C")
})

test_that("spouses returns empty for nodes with no bidirected edges", {
  admg <- caugi(
    A %-->% B %-->% C,
    class = "ADMG"
  )

  expect_equal(length(spouses(admg, "A")), 0L)
  expect_equal(length(spouses(admg, "B")), 0L)
})

# ─────────────────────────────────────────────────────────────────────────────
# Districts (C-Components)
# ─────────────────────────────────────────────────────────────────────────────

test_that("districts returns c-components", {
  admg <- caugi(
    A %-->% B,
    A %<->% C,
    D %<->% E,
    class = "ADMG"
  )

  dists <- districts(admg)

  # Should have 3 districts: {A,C}, {B}, {D,E}
  expect_equal(length(dists), 3L)

  # Check that A and C are in the same district
  a_dist <- dists[sapply(dists, function(d) "A" %in% d)][[1]]
  expect_true("C" %in% a_dist)

  # B should be alone
  b_dist <- dists[sapply(dists, function(d) "B" %in% d)][[1]]
  expect_equal(b_dist, "B")

  # D and E should be together
  d_dist <- dists[sapply(dists, function(d) "D" %in% d)][[1]]
  expect_true("E" %in% d_dist)
})

test_that("districts with only directed edges gives singletons", {
  admg <- caugi(
    A %-->% B %-->% C,
    class = "ADMG"
  )

  dists <- districts(admg)
  expect_equal(length(dists), 3L)
  # Each node is its own district
  for (d in dists) {
    expect_equal(length(d), 1L)
  }
})

# ─────────────────────────────────────────────────────────────────────────────
# M-Separation
# ─────────────────────────────────────────────────────────────────────────────

test_that("m_separated works for chain structures", {
  admg <- caugi(
    A %-->% B %-->% C,
    class = "ADMG"
  )

  # A and C not separated unconditionally
  expect_false(m_separated(admg, "A", "C"))

  # A and C separated given B
  expect_true(m_separated(admg, "A", "C", "B"))
})

test_that("m_separated works for collider structures", {
  admg <- caugi(
    A %-->% C,
    B %-->% C,
    class = "ADMG"
  )

  # A and B are m-separated unconditionally (collider at C blocks)
  expect_true(m_separated(admg, "A", "B"))

  # A and B NOT m-separated given C (conditioning on collider opens)
  expect_false(m_separated(admg, "A", "B", "C"))
})

test_that("m_separated handles bidirected confounding", {
  # Confounding without direct edge: L --> X, L --> Y
  # (no direct X --> Y edge)
  admg <- caugi(
    L %-->% X,
    L %-->% Y,
    class = "ADMG"
  )

  # X and Y not m-separated unconditionally (confounding via L)
  expect_false(m_separated(admg, "X", "Y"))

  # X and Y m-separated given L (blocks the confounding path)
  expect_true(m_separated(admg, "X", "Y", "L"))

  # With direct edge: L --> X --> Y, L --> Y
  admg2 <- caugi(
    L %-->% X,
    X %-->% Y,
    L %-->% Y,
    class = "ADMG"
  )

  # X and Y NOT m-separated even given L (direct edge X --> Y remains)
  expect_false(m_separated(admg2, "X", "Y", "L"))
})

# ─────────────────────────────────────────────────────────────────────────────
# Adjustment Functions
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_valid_adjustment_admg works for confounding", {
  admg <- caugi(
    L %-->% X,
    X %-->% Y,
    L %-->% Y,
    class = "ADMG"
  )

  # Empty set is not valid (backdoor through L)
  expect_false(is_valid_adjustment_admg(admg, X = "X", Y = "Y", Z = NULL))

  # L is valid
  expect_true(is_valid_adjustment_admg(admg, X = "X", Y = "Y", Z = "L"))
})

test_that("is_valid_adjustment_admg rejects forbidden descendants", {
  admg <- caugi(
    X %-->% M,
    M %-->% Y,
    L %-->% X,
    L %-->% Y,
    class = "ADMG"
  )

  # M is a descendant of X on causal path - not valid
  expect_false(is_valid_adjustment_admg(admg, X = "X", Y = "Y", Z = "M"))

  # L is valid
  expect_true(is_valid_adjustment_admg(admg, X = "X", Y = "Y", Z = "L"))
})

test_that("all_adjustment_sets_admg finds valid sets", {
  admg <- caugi(
    L %-->% X,
    X %-->% Y,
    L %-->% Y,
    class = "ADMG"
  )

  sets <- all_adjustment_sets_admg(admg, X = "X", Y = "Y", minimal = TRUE)

  # Should find {L} as minimal adjustment set
  expect_true(any(sapply(sets, function(s) identical(s, "L"))))
})

test_that("is_valid_adjustment_admg errors when X or Y is missing", {
  admg <- caugi(
    L %-->% X,
    X %-->% Y,
    L %-->% Y,
    class = "ADMG"
  )

  # Missing X

  expect_error(
    is_valid_adjustment_admg(admg, Y = "Y", Z = "L"),
    "X \\(or X_index\\) must be provided"
  )

  # Missing Y
  expect_error(
    is_valid_adjustment_admg(admg, X = "X", Z = "L"),
    "Y \\(or Y_index\\) must be provided"
  )

  # Missing both X and Y
  expect_error(
    is_valid_adjustment_admg(admg, Z = "L"),
    "X \\(or X_index\\) must be provided"
  )

  # Using indices should also work
  expect_true(is_valid_adjustment_admg(
    admg,
    X_index = 2L,
    Y_index = 3L,
    Z = "L"
  ))
})

test_that("all_adjustment_sets_admg errors when X or Y is missing", {
  admg <- caugi(
    L %-->% X,
    X %-->% Y,
    L %-->% Y,
    class = "ADMG"
  )

  # Missing X
  expect_error(
    all_adjustment_sets_admg(admg, Y = "Y"),
    "X \\(or X_index\\) must be provided"
  )

  # Missing Y
  expect_error(
    all_adjustment_sets_admg(admg, X = "X"),
    "Y \\(or Y_index\\) must be provided"
  )

  # Missing both X and Y
  expect_error(
    all_adjustment_sets_admg(admg),
    "X \\(or X_index\\) must be provided"
  )

  # Using indices should also work
  sets <- all_adjustment_sets_admg(
    admg,
    X_index = 2L,
    Y_index = 3L,
    minimal = TRUE
  )
  expect_true(any(sapply(sets, function(s) identical(s, "L"))))
})

# ─────────────────────────────────────────────────────────────────────────────
# Conversion Functions
# ─────────────────────────────────────────────────────────────────────────────

test_that("ADMG can be converted to dagitty", {
  skip_if_not_installed("dagitty")

  admg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )

  dg <- as_dagitty(admg)
  expect_s3_class(dg, "dagitty")

  # Check edges preserved
  dg_edges <- as.data.frame(dagitty::edges(dg))
  expect_true(nrow(dg_edges) >= 2L)
})

test_that("dagitty ADMG can be converted to caugi", {
  skip_if_not_installed("dagitty")

  dg <- dagitty::dagitty("mag { A -> B ; A <-> C }")
  cg <- as_caugi(dg, class = "ADMG")

  expect_true(is_admg(cg, force_check = TRUE))
  expect_equal(cg@graph_class, "ADMG")
})

test_that("ADMG can be converted to igraph", {
  skip_if_not_installed("igraph")

  admg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )

  ig <- as_igraph(admg)
  expect_s3_class(ig, "igraph")
  expect_equal(igraph::vcount(ig), 3L)
})

test_that("ADMG can be converted to adjacency matrix", {
  admg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )

  adj <- as_adjacency(admg)
  expect_equal(nrow(adj), 3L)
  expect_equal(ncol(adj), 3L)

  # A -> B: adj[A,B] = 1
  expect_equal(adj["A", "B"], 1L)

  # A <-> C: symmetric
  expect_equal(adj["A", "C"], 1L)
  expect_equal(adj["C", "A"], 1L)
})

# ─────────────────────────────────────────────────────────────────────────────
# Graph Query Functions
# ─────────────────────────────────────────────────────────────────────────────

test_that("parents and children work for ADMG", {
  admg <- caugi(
    A %-->% B,
    B %-->% C,
    A %<->% C,
    class = "ADMG"
  )

  expect_equal(parents(admg, "B"), "A")
  expect_equal(children(admg, "A"), "B")
  expect_equal(parents(admg, "C"), "B")
  expect_equal(children(admg, "B"), "C")
})

test_that("ancestors and descendants work for ADMG", {
  admg <- caugi(
    A %-->% B %-->% C,
    A %<->% D,
    class = "ADMG"
  )

  # Ancestors via directed edges only
  expect_equal(sort(ancestors(admg, "C")), c("A", "B"))

  # D has no ancestors (bidirected doesn't count)
  expect_equal(length(ancestors(admg, "D")), 0L)

  # Descendants via directed edges only
  expect_equal(sort(descendants(admg, "A")), c("B", "C"))
})

test_that("markov_blanket includes spouses", {
  admg <- caugi(
    L %-->% X,
    X %-->% Y,
    X %<->% Z,
    class = "ADMG"
  )

  mb_x <- markov_blanket(admg, "X")

  # MB(X) should include: Pa(X)={L}, Ch(X)={Y}, Sp(X)={Z}
  expect_true("L" %in% mb_x)
  expect_true("Y" %in% mb_x)
  expect_true("Z" %in% mb_x)
})

test_that("exogenous returns nodes without parents", {
  admg <- caugi(
    A %-->% B,
    C %<->% D,
    class = "ADMG"
  )

  exo <- exogenous(admg)

  # A, C, D have no parents (C <-> D doesn't count as parent)
  expect_true("A" %in% exo)
  expect_true("C" %in% exo)
  expect_true("D" %in% exo)
  expect_false("B" %in% exo)
})
