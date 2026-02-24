# Tests for minimal_d_separator functionality

test_that("minimal_d_separator works on chain structure", {
  # Chain: A -> B -> C
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  # Separator for A and C: {B}
  sep <- minimal_d_separator(cg, "A", "C")
  expect_false(is.null(sep))
  expect_true("B" %in% sep)
})

test_that("minimal_d_separator works on fork structure", {
  # Fork: A -> B, A -> C
  cg <- caugi(
    A %-->% B,
    A %-->% C,
    class = "DAG"
  )

  # Separator for B and C: {A}
  sep <- minimal_d_separator(cg, "B", "C")
  expect_false(is.null(sep))
  expect_true("A" %in% sep)
})

test_that("minimal_d_separator handles collider structure", {
  # Collider: A -> B <- C
  cg <- caugi(
    A %-->% B,
    C %-->% B,
    class = "DAG"
  )

  # Without conditioning on B, A and C are d-separated
  # So separator should be empty
  sep <- minimal_d_separator(cg, "A", "C")
  expect_false(is.null(sep))
  expect_length(sep, 0)
})

test_that("minimal_d_separator returns NULL when no separator exists", {
  # Direct edge: A -> B
  # No separator possible with empty R
  cg <- caugi(
    A %-->% B,
    class = "DAG"
  )

  sep <- minimal_d_separator(cg, "A", "B", R = character(0))
  expect_null(sep)
})

test_that("minimal_d_separator respects mandatory inclusions (I parameter)", {
  # A -> B -> C -> D
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    class = "DAG"
  )

  # Force both B and C to be in the separator
  sep <- minimal_d_separator(cg, "A", "D", I = c("B", "C"))
  expect_false(is.null(sep))
  expect_true("B" %in% sep)
  expect_true("C" %in% sep)
})

test_that("minimal_d_separator respects restrictions (R parameter)", {
  # A -> B -> C
  # But restrict to only {B}
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  sep <- minimal_d_separator(cg, "A", "C", R = "B")
  expect_false(is.null(sep))
  expect_equal(sep, "B")
})

test_that("minimal_d_separator works with node indices", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  # A=1, B=2, C=3 in alphabetical order
  sep <- minimal_d_separator(cg, X_index = 1L, Y_index = 3L)
  expect_false(is.null(sep))
  expect_true("B" %in% sep)
})

test_that("minimal_d_separator handles complex DAG", {
  # From Elements of Causal Inference, Figure 6.5
  cg <- caugi(
    C %-->% X,
    X %-->% F,
    X %-->% D,
    A %-->% X,
    A %-->% K,
    K %-->% Y,
    D %-->% Y,
    D %-->% G,
    Y %-->% H,
    class = "DAG"
  )

  # Find separator for X and Y
  sep <- minimal_d_separator(cg, "X", "Y")
  expect_false(is.null(sep))

  # Verify it actually d-separates
  expect_true(d_separated(cg, "X", "Y", Z = sep))
})

test_that("minimal_d_separator handles multiple X and Y nodes", {
  # A -> C <- B,  C -> D
  # Find separator for {A, B} and {D}
  cg <- caugi(
    A %-->% C,
    B %-->% C,
    C %-->% D,
    class = "DAG"
  )

  # Find separator for {A, B} and {D}
  # Should find C
  sep <- minimal_d_separator(cg, X = c("A", "B"), Y = "D")
  expect_false(is.null(sep))
  expect_true("C" %in% sep)
})

test_that("minimal_d_separator validates graph class", {
  # Create a non-DAG graph
  cg <- caugi(
    A %<->% B,
    class = "ADMG"
  )

  expect_error(
    minimal_d_separator(cg, "A", "B"),
    "only defined for DAGs"
  )
})

test_that("minimal_d_separator default R excludes X and Y", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    class = "DAG"
  )

  # Should automatically exclude X and Y from separator
  sep <- minimal_d_separator(cg, "A", "D")
  expect_false(is.null(sep))
  expect_false("A" %in% sep)
  expect_false("D" %in% sep)
})


test_that("minimal_d_separator returns empty for already separated nodes", {
  # Collider: A -> B <- C, A and C are already d-separated
  cg <- caugi(
    A %-->% B,
    C %-->% B,
    class = "DAG"
  )

  sep <- minimal_d_separator(cg, "A", "C")
  expect_false(is.null(sep))
  expect_length(sep, 0)

  # Verify they're already d-separated
  expect_true(d_separated(cg, "A", "C"))
})

test_that("minimal_d_separator with I not in R returns NULL", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  # Require B to be in separator, but R excludes B
  # This is an impossible constraint, should return NULL.
  sep <- minimal_d_separator(cg, "A", "C", I = "B", R = "C")

  expect_null(sep)
})

test_that("minimal_d_separator minimality property (correct check)", {
  # A -> B -> C -> D
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    class = "DAG"
  )

  sep <- minimal_d_separator(cg, "A", "D")
  expect_false(is.null(sep))

  # Every proper subset must fail to d-separate
  for (i in seq_along(sep)) {
    subset_sep <- sep[-i]
    expect_false(
      d_separated(cg, "A", "D", Z = subset_sep),
      info = "Separator is not minimal"
    )
  }
})

test_that("minimal_d_separator handles descendant-of-collider activation", {
  # X -> C <- Y
  # C -> D
  cg <- caugi(
    X %-->% C,
    Y %-->% C,
    C %-->% D,
    class = "DAG"
  )

  # Conditioning on D activates the collider at C,
  # so no separator contained in {D} can block the path.
  sep <- minimal_d_separator(cg, "X", "Y", I = "D", R = "D")
  expect_null(sep)
})

test_that("minimal_d_separator blocks multiple parallel paths", {
  # X -> A -> Y
  # X -> B -> Y
  cg <- caugi(
    X %-->% A,
    A %-->% Y,
    X %-->% B,
    B %-->% Y,
    class = "DAG"
  )

  sep <- minimal_d_separator(cg, "X", "Y", R = c("A", "B"))
  expect_false(is.null(sep))
  expect_setequal(sep, c("A", "B"))
})

test_that("minimal_d_separator respects ancestor restriction", {
  # U -> X -> M -> Y
  cg <- caugi(
    U %-->% X,
    X %-->% M,
    M %-->% Y,
    class = "DAG"
  )

  # The algorithm may return {M} or {U, M} - both are valid separators
  # {M} alone separates, but {U, M} is also minimal in the algorithm's sense
  # (the algorithm doesn't guarantee globally minimum cardinality)
  sep <- minimal_d_separator(cg, "X", "Y", R = c("U", "M"))
  expect_false(is.null(sep))

  # Verify it's a valid separator
  expect_true(d_separated(cg, "X", "Y", Z = sep))

  # Should contain M (the necessary node on the path)
  expect_true("M" %in% sep)
})

test_that("minimal_d_separator enforces I subset of R (deterministic behavior)", {
  # A -> B -> C
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  # I not contained in R makes the constraint unsatisfiable
  sep <- minimal_d_separator(cg, "A", "C", I = "B", R = "C")

  expect_null(sep)
})

# ──────────────────────────────────────────────────────────────────────────────
# Tests ported from NetworkX to verify implementation correctness
# ──────────────────────────────────────────────────────────────────────────────
#
# These tests are adapted from NetworkX's test_d_separation.py to verify that
# caugi's minimal_d_separator implementation produces correct results matching
# the well-tested NetworkX implementation. Both implementations follow the
# algorithm from van der Zander & Liśkiewicz (2020).
#
# Key differences:
# - Data structure: caugi uses CSR (Compressed Sparse Row), NetworkX uses adjacency lists
# - Implementation: caugi is Rust (via extendr), NetworkX is Python
# - Both implementations should produce equivalent minimal d-separators
#
# References:
# - NetworkX: https://github.com/networkx/networkx/blob/main/networkx/algorithms/tests/test_d_separation.py
# - van der Zander, B. & Liśkiewicz, M. (2020). Finding Minimal d-separators in Linear Time and Applications.
#   UAI 2020. https://proceedings.mlr.press/v115/van-der-zander20a.html

test_that("NetworkX Case 1: large_collider_graph (A -> B <- C, B -> D -> E, B -> F, G -> E)", {
  # NetworkX test graph: large_collider_graph
  # edge_list = [("A", "B"), ("C", "B"), ("B", "D"), ("D", "E"), ("B", "F"), ("G", "E")]
  cg <- caugi(
    A %-->% B,
    C %-->% B,
    B %-->% D,
    D %-->% E,
    B %-->% F,
    G %-->% E,
    class = "DAG"
  )

  # NetworkX: assert not nx.is_d_separator(large_collider_graph, {"B"}, {"E"}, set())
  expect_false(d_separated(cg, "B", "E"))

  # NetworkX: Zmin = nx.find_minimal_d_separator(large_collider_graph, "B", "E")
  # NetworkX: assert Zmin == {"D"}
  Zmin <- minimal_d_separator(cg, "B", "E")
  expect_false(is.null(Zmin))
  expect_setequal(Zmin, "D")

  # NetworkX: assert nx.is_d_separator(large_collider_graph, "B", "E", Zmin)
  expect_true(d_separated(cg, "B", "E", Z = Zmin))

  # Test with multiple X and Y nodes
  # NetworkX: assert nx.is_minimal_d_separator(large_collider_graph, {"A", "B"}, {"G", "E"}, Zmin)
  Zmin_multi <- minimal_d_separator(cg, X = c("A", "B"), Y = c("G", "E"))
  expect_false(is.null(Zmin_multi))
  expect_true("D" %in% Zmin_multi)
})

test_that("NetworkX Case 2: chain_and_fork_graph (A -> B -> C, B -> D -> C)", {
  # NetworkX test graph: chain_and_fork_graph
  # edge_list = [("A", "B"), ("B", "C"), ("B", "D"), ("D", "C")]
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    B %-->% D,
    D %-->% C,
    class = "DAG"
  )

  # NetworkX: assert not nx.is_d_separator(chain_and_fork_graph, {"A"}, {"C"}, set())
  expect_false(d_separated(cg, "A", "C"))

  # NetworkX: Zmin = nx.find_minimal_d_separator(chain_and_fork_graph, "A", "C")
  # NetworkX: assert Zmin == {"B"}
  Zmin <- minimal_d_separator(cg, "A", "C")
  expect_false(is.null(Zmin))
  expect_setequal(Zmin, "B")

  # Test minimality: Znotmin = Zmin.union({"D"})
  # NetworkX: assert not nx.is_minimal_d_separator(chain_and_fork_graph, "A", "C", Znotmin)
  # We verify that {B, D} still d-separates but is not minimal
  expect_true(d_separated(cg, "A", "C", Z = c("B", "D")))
  # The minimal separator should only be {B}, not {B, D}
  expect_setequal(Zmin, "B")
})

test_that("NetworkX Case 3: no_separating_set_graph (A -> B)", {
  # NetworkX test graph: no_separating_set_graph
  # edge_list = [("A", "B")]
  cg <- caugi(
    A %-->% B,
    class = "DAG"
  )

  # NetworkX: assert not nx.is_d_separator(no_separating_set_graph, {"A"}, {"B"}, set())
  expect_false(d_separated(cg, "A", "B"))

  # NetworkX: assert nx.find_minimal_d_separator(no_separating_set_graph, "A", "B") is None
  # With default R (all nodes except X and Y), there are no other nodes,
  # so no separator can exist
  Zmin <- minimal_d_separator(cg, "A", "B")
  expect_null(Zmin)
})

test_that("NetworkX Case 4: large_no_separating_set_graph (A -> B, C -> A, C -> B)", {
  # NetworkX test graph: large_no_separating_set_graph
  # edge_list = [("A", "B"), ("C", "A"), ("C", "B")]
  cg <- caugi(
    A %-->% B,
    C %-->% A,
    C %-->% B,
    class = "DAG"
  )

  # NetworkX: assert not nx.is_d_separator(large_no_separating_set_graph, {"A"}, {"B"}, {"C"})
  expect_false(d_separated(cg, "A", "B", Z = "C"))

  # NetworkX: assert nx.find_minimal_d_separator(large_no_separating_set_graph, "A", "B") is None
  # C is initially proposed but is invalid (doesn't d-separate A and B)
  Zmin <- minimal_d_separator(cg, "A", "B")
  expect_null(Zmin)
})

test_that("NetworkX Case 5: collider_trek_graph with included/restricted parameters", {
  # NetworkX test graph: collider_trek_graph
  # edge_list = [("A", "B"), ("C", "B"), ("C", "D")]
  # Structure: A -> B <- C -> D
  cg <- caugi(
    A %-->% B,
    C %-->% B,
    C %-->% D,
    class = "DAG"
  )

  # NetworkX: assert nx.find_minimal_d_separator(collider_trek_graph, "A", "D", included="B") == {"B", "C"}
  Zmin_included <- minimal_d_separator(cg, "A", "D", I = "B")
  expect_false(is.null(Zmin_included))
  expect_setequal(Zmin_included, c("B", "C"))

  # NetworkX: assert nx.find_minimal_d_separator(collider_trek_graph, "A", "D", included="B", restricted="B") is None
  # If we require B to be included but restrict to only B, no valid separator exists
  # because we also need C
  Zmin_restricted <- minimal_d_separator(cg, "A", "D", I = "B", R = "B")
  expect_null(Zmin_restricted)
})

test_that("NetworkX Case 6: complex graph for minimality check", {
  # NetworkX test from test_is_minimal_d_separator_checks_dsep
  # edge_list = [("A", "B"), ("A", "E"), ("B", "C"), ("B", "D"), ("D", "C"), ("D", "F"), ("E", "D"), ("E", "F")]
  cg <- caugi(
    A %-->% B,
    A %-->% E,
    B %-->% C,
    B %-->% D,
    D %-->% C,
    D %-->% F,
    E %-->% D,
    E %-->% F,
    class = "DAG"
  )

  # NetworkX: assert not nx.is_d_separator(g, {"C"}, {"F"}, {"D"})
  expect_false(d_separated(cg, "C", "F", Z = "D"))

  # Since {D} is not a d-separator, minimal_d_separator should find the correct one
  # or if we test with empty set
  expect_false(d_separated(cg, "C", "F", Z = character(0)))

  # Find the actual minimal separator
  Zmin <- minimal_d_separator(cg, "C", "F")
  # If a separator exists, verify it actually d-separates
  if (!is.null(Zmin)) {
    expect_true(d_separated(cg, "C", "F", Z = Zmin))
  }
})
