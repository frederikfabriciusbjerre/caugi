# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Topological Sort tests ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# Helper function to verify topological ordering
# For every edge u -> v, u must appear before v in the ordering
verify_topo_order <- function(cg, order) {
  edges_df <- as.data.frame(edges(cg))
  directed_edges <- edges_df[edges_df$edge == "-->", ]

  if (nrow(directed_edges) == 0) {
    return(TRUE)
  }

  pos <- .set_names(seq_along(order), order)

  for (i in seq_len(nrow(directed_edges))) {
    from_node <- directed_edges$from[i]
    to_node <- directed_edges$to[i]

    if (pos[from_node] >= pos[to_node]) {
      return(FALSE)
    }
  }
  return(TRUE)
}

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Basic DAG ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("topological_sort works on simple chain DAG", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  order <- topological_sort(cg)

  expect_equal(length(order), 3L)
  expect_setequal(order, c("A", "B", "C"))
  expect_true(verify_topo_order(cg, order))
})

test_that("topological_sort works on diamond DAG", {
  cg <- caugi(
    A %-->% B,
    A %-->% C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  order <- topological_sort(cg)

  expect_equal(length(order), 4L)
  expect_setequal(order, c("A", "B", "C", "D"))
  expect_true(verify_topo_order(cg, order))
})

test_that("topological_sort works with isolated nodes", {
  cg <- caugi(
    A %-->% B,
    C, # isolated node
    class = "DAG"
  )

  order <- topological_sort(cg)

  expect_equal(length(order), 3L)
  expect_setequal(order, c("A", "B", "C"))
  expect_true(verify_topo_order(cg, order))
})

test_that("topological_sort works on empty DAG (no edges)", {
  cg <- caugi(
    A,
    B,
    C,
    class = "DAG"
  )

  order <- topological_sort(cg)

  expect_equal(length(order), 3L)
  expect_setequal(order, c("A", "B", "C"))
})

test_that("topological_sort works on single node DAG", {
  cg <- caugi(
    A,
    class = "DAG"
  )

  order <- topological_sort(cg)

  expect_equal(order, "A")
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Errors ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("topological_sort errors on ADMG", {
  cg <- caugi(
    L %-->% X,
    X %-->% Y,
    L %-->% Y,
    class = "ADMG"
  )

  expect_error(topological_sort(cg), "only defined for DAGs")
})

test_that("topological_sort errors on PDAG", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %-->% D,
    class = "PDAG"
  )

  expect_error(topological_sort(cg), "only defined for DAGs")
})

test_that("topological_sort errors on UG", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )

  expect_error(topological_sort(cg), "only defined for DAGs")
})

test_that("topological_sort errors on non-caugi input", {
  expect_error(topological_sort("not a caugi"), "Input must be a caugi")
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Comparison with igraph ──────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("topological_sort matches igraph on simple DAG", {
  skip_if_not_installed("igraph")

  cg <- caugi(
    A %-->% B,
    B %-->% C,
    A %-->% C,
    class = "DAG"
  )

  # Get caugi's topological sort
  caugi_order <- topological_sort(cg)

  # Convert to igraph and get its topological sort
  ig <- as_igraph(cg)
  ig_order <- names(igraph::topo_sort(ig))

  # Both should be valid topological orderings
  expect_true(verify_topo_order(cg, caugi_order))
  expect_true(verify_topo_order(cg, ig_order))

  # Both should have all nodes
  expect_setequal(caugi_order, ig_order)
})

test_that("topological_sort is valid on random DAGs (igraph comparison)", {
  skip_if_not_installed("igraph")

  set.seed(42)

  # Test on multiple random graphs

  for (i in 1:5) {
    # Generate random DAG using igraph
    g <- igraph::sample_pa(50, directed = TRUE)
    igraph::V(g)$name <- paste0("V", seq_len(igraph::vcount(g)))

    # Convert to caugi
    cg <- as_caugi(g, class = "DAG")

    # Get topological orderings
    caugi_order <- topological_sort(cg)
    ig_order <- names(igraph::topo_sort(g))

    # Both should be valid topological orderings
    expect_true(verify_topo_order(cg, caugi_order))
    expect_true(verify_topo_order(cg, ig_order))

    # Both should have all nodes
    expect_setequal(caugi_order, ig_order)
  }
})

test_that("topological_sort is valid on larger random DAGs", {
  skip_if_not_installed("igraph")

  set.seed(123)

  # Test on larger graphs
  g <- igraph::sample_pa(500, directed = TRUE)
  igraph::V(g)$name <- paste0("V", seq_len(igraph::vcount(g)))

  cg <- as_caugi(g, class = "DAG")

  # Get topological ordering
  caugi_order <- topological_sort(cg)

  # Verify it's valid
  expect_true(verify_topo_order(cg, caugi_order))

  # Should have all nodes
  expect_equal(length(caugi_order), 500L)
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Property-based tests ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("topological_sort returns all nodes exactly once", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    E, # isolated
    class = "DAG"
  )

  order <- topological_sort(cg)

  # All nodes present

  expect_setequal(order, c("A", "B", "C", "D", "E"))

  # No duplicates
  expect_equal(length(order), length(unique(order)))
})

test_that("topological_sort builds the graph if needed", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")

  # Graph should not be built yet
  expect_true(!is.null(cg@session))

  # topological_sort should trigger build
  order <- topological_sort(cg)

  # Graph should be built now
  expect_true(!is.null(cg@session))

  # Result should be valid
  expect_equal(length(order), 3L)
  expect_true(verify_topo_order(cg, order))
})
