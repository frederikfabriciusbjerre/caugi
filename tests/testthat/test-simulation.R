test_that("errors: n invalid", {
  expect_error(generate_graph(0, m = 0), "n must be a single integer > 0")
  expect_error(generate_graph(c(2, 3), m = 1), "n must be a single integer > 0")
})

test_that("errors: supply exactly one of m or p", {
  expect_error(generate_graph(5), "exactly one of m or p")
  expect_error(generate_graph(5, m = 2, p = 0.1), "exactly one of m or p")
})

test_that("errors: p invalid", {
  expect_error(generate_graph(4, p = -0.1), "p must be in \\[0,1\\]")
  expect_error(generate_graph(4, p = 1.1), "p must be in \\[0,1\\]")
  expect_error(generate_graph(4, p = NA_real_), "p must be in \\[0,1\\]")
  expect_error(generate_graph(4, p = c(0.1, 0.2)), "p must be in \\[0,1\\]")
})

test_that("errors: m invalid", {
  n <- 4
  tot <- n * (n - 1) / 2
  expect_error(generate_graph(n, m = -1L), "m must be in 0..")
  expect_error(generate_graph(n, m = tot + 1L), "m must be in 0..")
  expect_error(generate_graph(n, m = c(1L, 2L)), "m must be in 0..")
})

test_that("DAG class with m = 0 yields 0 edges and correct nodes", {
  n <- 5
  g <- generate_graph(n, m = 0L, class = "DAG")
  expect_equal(g@graph_class, "DAG")
  expect_equal(nrow(nodes(g)), n)
  expect_equal(nrow(edges(g)), 0L)
  expect_identical(nodes(g)$name, paste0("V", seq_len(n)))
})

test_that("DAG class with p = 0 yields 0 edges", {
  g <- generate_graph(6, p = 0, class = "DAG")
  expect_identical(nrow(edges(g)), 0L)
  expect_true(all(edge_types(g) %in% character()))
})

test_that("m = tot yields a tournament DAG of size n", {
  n <- 6
  tot <- n * (n - 1) / 2
  set.seed(11)
  g <- generate_graph(n, m = tot, class = "DAG")
  expect_equal(nrow(edges(g)), tot)
  expect_true(all(edge_types(g) %in% "-->"))
  # no duplicate undirected pairs
  ed <- edges(g)
  key <- paste(pmin(ed$from, ed$to), pmax(ed$from, ed$to))
  expect_equal(length(unique(key)), tot)
})

test_that("reproducible with same seed", {
  set.seed(42)
  g1 <- generate_graph(7, m = 8, class = "DAG")
  set.seed(42)
  g2 <- generate_graph(7, m = 8, class = "DAG")
  expect_identical(nodes(g1), nodes(g2))
  expect_identical(
    edges(g1),
    edges(g2)
  )
})

test_that("p branch draws edges via rbinom", {
  n <- 7
  tot <- n * (n - 1) / 2
  p <- 0.25
  set.seed(123)
  expected_m <- stats::rbinom(1L, tot, p)
  set.seed(123)
  g <- generate_graph(n, p = p, class = "DAG")
  expect_identical(nrow(edges(g)), expected_m)
})

test_that("CPDAG class returns PDAG class and same nodes", {
  g <- generate_graph(6, m = 5, class = "CPDAG")
  expect_identical(g@graph_class, "PDAG")
  expect_identical(nrow(nodes(g)), 6L)
})

test_that("CPDAG generation returns a valid CPDAG with supported edge types", {
  set.seed(2026)
  g <- generate_graph(10, m = 14L, class = "CPDAG")

  expect_identical(g@graph_class, "PDAG")
  expect_true(is_pdag(g))
  expect_true(is_cpdag(g))
  expect_true(is_acyclic(g, force_check = TRUE))
  expect_true(all(edge_types(g) %in% c("-->", "---")))
})

test_that("CPDAG generation preserves sampled skeleton from DAG branch", {
  set.seed(1234)
  dag <- generate_graph(8, m = 9L, class = "DAG")

  set.seed(1234)
  cpdag <- generate_graph(8, m = 9L, class = "CPDAG")

  normalized_skeleton <- function(g) {
    edges(skeleton(g))[order(from, to, edge)]
  }

  expect_equal(normalized_skeleton(cpdag), normalized_skeleton(dag))
  expect_true(is_cpdag(cpdag))
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── simulate_data tests ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────── Input validation ────────────────────────────────

test_that("simulate_data: errors on non-caugi input", {
  expect_error(simulate_data(list(), n = 10), "must be a caugi")
})
test_that("simulate_data: errors on non-DAG graph class", {
  pdag <- caugi(A %-->% B, B %---% C, class = "PDAG")
  expect_error(simulate_data(pdag, n = 10), "only supports DAGs")

  admg <- caugi(A %-->% B, A %<->% C, class = "ADMG")
  expect_error(simulate_data(admg, n = 10), "only supports DAGs")

  ug <- caugi(A %---% B, class = "UG")
  expect_error(simulate_data(ug, n = 10), "only supports DAGs")
})

test_that("simulate_data: errors on empty graph", {
  empty_dag <- caugi(class = "DAG")
  expect_error(simulate_data(empty_dag, n = 10), "empty graph")
})

test_that("simulate_data: errors on invalid n", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(simulate_data(cg, n = 0), "n must be a single integer > 0")
  expect_error(simulate_data(cg, n = -5), "n must be a single integer > 0")
  expect_error(
    simulate_data(cg, n = c(10, 20)),
    "n must be a single integer > 0"
  )
})

test_that("simulate_data: errors on unknown node in equations", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    simulate_data(cg, n = 10, X = rnorm(n)),
    "Unknown node"
  )
})

test_that("simulate_data: errors on equation length mismatch", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    simulate_data(cg, n = 10, A = rnorm(5)),
    "produced 5 values, expected 10"
  )
})

test_that("simulate_data: errors when custom equation doesn't reference all parents", {
  cg <- caugi(A %-->% B, C %-->% B, class = "DAG")

  # Missing both parents
  expect_error(
    simulate_data(cg, n = 10, B = rnorm(n)),
    "must reference all parent nodes"
  )

  # Missing one parent
  expect_error(
    simulate_data(cg, n = 10, B = 0.5 * A + rnorm(n)),
    "Missing: C"
  )

  # All parents referenced - should work
  expect_no_error(
    simulate_data(cg, n = 10, B = 0.5 * A + 0.3 * C + rnorm(n))
  )
})

# ─────────────────────────── Output structure ─────────────────────────────────

test_that("simulate_data: returns data.frame with correct dimensions", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  df <- simulate_data(cg, n = 100, seed = 1)

  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 100L)
  expect_equal(ncol(df), 3L)
})

test_that("simulate_data: column names match node names", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  df <- simulate_data(cg, n = 50, seed = 1)

  expect_identical(colnames(df), nodes(cg)$name)
})

test_that("simulate_data: column order matches node order", {
  cg <- caugi(
    nodes = c("X", "Y", "Z"),
    from = c("X", "Y"),
    edge = c("-->", "-->"),
    to = c("Y", "Z"),
    class = "DAG"
  )
  df <- simulate_data(cg, n = 50, seed = 1)

  expect_identical(colnames(df), c("X", "Y", "Z"))
})

# ──────────────────────────── Reproducibility ─────────────────────────────────

test_that("simulate_data: reproducible with seed", {
  cg <- caugi(A %-->% B, B %-->% C, A %-->% C, class = "DAG")

  df1 <- simulate_data(cg, n = 100, seed = 42)
  df2 <- simulate_data(cg, n = 100, seed = 42)

  expect_identical(df1, df2)
})

test_that("simulate_data: different seeds produce different data", {
  cg <- caugi(A %-->% B, class = "DAG")

  df1 <- simulate_data(cg, n = 100, seed = 1)
  df2 <- simulate_data(cg, n = 100, seed = 2)

  expect_false(identical(df1, df2))
})

# ─────────────────────────── Standardization ──────────────────────────────────

test_that("simulate_data: standardize = TRUE yields mean ~ 0 and sd ~ 1", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  df <- simulate_data(cg, n = 1000, standardize = TRUE, seed = 123)

  for (col in colnames(df)) {
    expect_equal(mean(df[[col]]), 0, tolerance = 1e-10)
    expect_equal(sd(df[[col]]), 1, tolerance = 1e-10)
  }
})

test_that("simulate_data: standardize = FALSE does not standardize", {
  cg <- caugi(A %-->% B, class = "DAG")
  df <- simulate_data(cg, n = 1000, standardize = FALSE, seed = 42)

  # With auto-generated data, unlikely to have exact mean 0 / sd 1
  # At least one column should differ noticeably
  means_zero <- all(abs(sapply(df, mean)) < 0.01)
  sds_one <- all(abs(sapply(df, sd) - 1) < 0.01)

  # Not both should be true (very unlikely by chance)
  expect_false(means_zero && sds_one)
})

# ───────────────────────────── Custom equations ───────────────────────────────

test_that("simulate_data: custom equations are applied", {
  cg <- caugi(A %-->% B, class = "DAG")
  df <- simulate_data(
    cg,
    n = 100,
    standardize = FALSE,
    A = rep(5, n),
    B = A + 1
  )

  expect_true(all(df$A == 5))
  expect_true(all(df$B == 6))
})

test_that("simulate_data: parent variables accessible in equations", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  df <- simulate_data(
    cg,
    n = 50,
    standardize = FALSE,
    seed = 1,
    A = rep(1, n),
    B = 2 * A,
    C = 3 * B
  )

  expect_true(all(df$A == 1))
  expect_true(all(df$B == 2))
  expect_true(all(df$C == 6))
})

test_that("simulate_data: n is available in custom equations", {
  cg <- caugi(A %-->% B, class = "DAG")
  df <- simulate_data(cg, n = 75, standardize = FALSE, A = seq_len(n))

  expect_equal(df$A, 1:75)
})

test_that("simulate_data: mix of custom and auto-generated", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  df <- simulate_data(
    cg,
    n = 100,
    standardize = FALSE,
    seed = 1,
    A = rep(10, n)
  )

  # A is custom
  expect_true(all(df$A == 10))

  # B and C are auto-generated, should have variation
  expect_true(sd(df$B) > 0)
  expect_true(sd(df$C) > 0)
})

# ────────────────────────── Coefficient behavior ──────────────────────────────

test_that("simulate_data: endogenous nodes correlate with parents", {
  cg <- caugi(A %-->% B, class = "DAG")
  df <- simulate_data(cg, n = 10000, standardize = FALSE, seed = 1)

  # Should have meaningful correlation (coefs are 0.1 to 0.9)
  r <- cor(df$A, df$B)
  expect_true(abs(r) > 0.05)
})

# ────────────────────────────── Edge cases ────────────────────────────────────

test_that("simulate_data: single node graph works", {
  cg <- caugi(A, class = "DAG")
  df <- simulate_data(cg, n = 50, seed = 1)

  expect_equal(nrow(df), 50L)
  expect_equal(ncol(df), 1L)
  expect_identical(colnames(df), "A")
})

test_that("simulate_data: graph with no edges (all exogenous)", {
  cg <- caugi(A, B, C, class = "DAG")
  df <- simulate_data(cg, n = 100, standardize = FALSE, seed = 1)

  expect_equal(ncol(df), 3L)
  # All columns should have independent noise
  expect_true(sd(df$A) > 0)
  expect_true(sd(df$B) > 0)
  expect_true(sd(df$C) > 0)
})

test_that("simulate_data: deep chain graph", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    D %-->% E,
    class = "DAG"
  )
  df <- simulate_data(cg, n = 100, seed = 1)

  expect_equal(ncol(df), 5L)
  expect_identical(colnames(df), c("A", "B", "C", "D", "E"))
})

test_that("simulate_data: wide graph (multiple children)", {
  cg <- caugi(
    A %-->% B + C + D + E,
    class = "DAG"
  )
  df <- simulate_data(cg, n = 100, seed = 1)

  expect_equal(ncol(df), 5L)
})

test_that("simulate_data: collider structure", {
  cg <- caugi(A %-->% C, B %-->% C, class = "DAG")
  df <- simulate_data(cg, n = 10000, standardize = FALSE, seed = 1)

  # A and B should be independent (uncorrelated)
  r_ab <- cor(df$A, df$B)
  expect_true(abs(r_ab) < 0.05)

  # C should correlate with both A and B
  r_ac <- cor(df$A, df$C)
  r_bc <- cor(df$B, df$C)
  expect_true(abs(r_ac) > 0.05)
  expect_true(abs(r_bc) > 0.05)
})
