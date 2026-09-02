# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Metrics tests ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────── SHD ──────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("SHD: identical graphs have SHD of 0", {
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(A %-->% B, B %-->% C)
  expect_equal(shd(cg1, cg2), 0)
  expect_equal(shd(cg1, cg2, normalized = TRUE), 0)
})

test_that("SHD: graphs with different nodes errors", {
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(A %-->% B, B %-->% D)
  expect_error(shd(cg1, cg2), "Graphs must have the same nodes")
})

test_that("SHD: shd gives correct results for different with one edge difference", {
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(A %-->% B, B %---% C)
  cg3 <- caugi(A %-->% B, B %<->% C)
  cg4 <- caugi(A %-->% B, B %o->% C)
  cg5 <- caugi(A %-->% B, B %--o% C)
  cg6 <- caugi(A %-->% B, B %o-o% C)

  results <- c(
    shd(cg1, cg2),
    shd(cg1, cg3),
    shd(cg1, cg4),
    shd(cg1, cg5),
    shd(cg1, cg6)
  )

  expect_equal(results, rep(results[1], length(results)))
})

test_that("SHD: graphs with custom nodes work", {
  reset_caugi_registry()
  register_caugi_edge("<--", "arrow", "tail", "directed", FALSE)

  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(B %<--% A)

  expect_equal(shd(cg1, cg2), 0)

  reset_caugi_registry()
})

test_that("SHD: symmetrical node relations work with shd", {
  cg1 <- caugi(A %---% B)
  cg2 <- caugi(B %---% A)

  expect_equal(shd(cg1, cg2), 0)
})

test_that("HD: same graphs but written in different ways work with shd", {
  reset_caugi_registry()

  register_caugi_edge("<--", "arrow", "tail", "directed", FALSE)

  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(C %<--% B, B %<--% A)

  expect_equal(shd(cg1, cg2), 0)
  reset_caugi_registry()
})

test_that("SHD: different edge declaration order gives SHD 0 (PDAG)", {
  # This is the exact bug case from the issue
  cg1 <- caugi(A %---% B, A %-->% C, D %-->% C, class = "PDAG")
  cg2 <- caugi(D %-->% C, A %---% B, A %-->% C, class = "PDAG")
  expect_equal(shd(cg1, cg2), 0)
  expect_equal(shd(cg1, cg2, normalized = TRUE), 0)
})

test_that("SHD: different edge declaration order gives SHD 0 (DAG)", {
  cg1 <- caugi(A %-->% B, B %-->% C, D %-->% C, class = "DAG")
  cg2 <- caugi(D %-->% C, B %-->% C, A %-->% B, class = "DAG")
  expect_equal(shd(cg1, cg2), 0)
})

test_that("SHD: completely reversed edge order gives SHD 0", {
  cg1 <- caugi(A %-->% B, B %-->% C, C %-->% D, D %-->% E, class = "DAG")
  cg2 <- caugi(D %-->% E, C %-->% D, B %-->% C, A %-->% B, class = "DAG")
  expect_equal(shd(cg1, cg2), 0)
})

test_that("SHD: shuffled edge order gives SHD 0 for mixed edge types", {
  # Mix of directed, undirected, and bidirected edges
  cg1 <- caugi(A %-->% B, B %---% C, C %<->% D, D %-->% E)
  cg2 <- caugi(C %<->% D, A %-->% B, D %-->% E, B %---% C)
  expect_equal(shd(cg1, cg2), 0)
})

test_that("SHD: same graph with explicit node order gives SHD 0", {
  cg1 <- caugi(A %-->% B, B %-->% C, nodes = c("A", "B", "C"))
  cg2 <- caugi(A %-->% B, B %-->% C, nodes = c("C", "B", "A"))
  expect_equal(shd(cg1, cg2), 0)
})

test_that("SHD: detects actual differences despite different edge order", {
  # cg1 has A-->B, cg2 has A---B (different edge type)
  cg1 <- caugi(A %-->% B, B %-->% C, class = "PDAG")
  cg2 <- caugi(B %-->% C, A %---% B, class = "PDAG")
  expect_equal(shd(cg1, cg2), 1)
})

test_that("SHD: larger graph with shuffled edges gives SHD 0", {
  # 6-node graph with multiple edges, shuffled order
  cg1 <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    D %-->% E,
    E %-->% F,
    A %-->% F,
    class = "DAG"
  )
  cg2 <- caugi(
    E %-->% F,
    A %-->% F,
    C %-->% D,
    A %-->% B,
    D %-->% E,
    B %-->% C,
    class = "DAG"
  )
  expect_equal(shd(cg1, cg2), 0)
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────────── HD ──────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("HD: identical graphs have HD of 0", {
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(A %-->% B, B %-->% C)
  expect_equal(hd(cg1, cg2), 0)
  expect_equal(hd(cg1, cg2, normalized = TRUE), 0)
})

test_that("HD: graphs with different nodes errors", {
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(A %-->% B, B %-->% D)
  expect_error(hd(cg1, cg2), "Graphs must have the same nodes")
})

test_that("HD: hd gives correct results for different with one edge difference", {
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(A %-->% B, B %---% C)
  cg3 <- caugi(A %-->% B, B %<->% C)
  cg4 <- caugi(A %-->% B, B %o->% C)
  cg5 <- caugi(A %-->% B, B %--o% C)
  cg6 <- caugi(A %-->% B, B %o-o% C)

  results <- c(
    hd(cg1, cg2),
    hd(cg1, cg3),
    hd(cg1, cg4),
    hd(cg1, cg5),
    hd(cg1, cg6)
  )

  expect_equal(results, rep(results[1], length(results)))
})

test_that("HD: graphs with custom nodes work", {
  reset_caugi_registry()
  register_caugi_edge("<--", "arrow", "tail", "directed", FALSE)

  cg1 <- caugi(A %-->% B)
  cg2 <- caugi(B %<--% A)

  expect_equal(hd(cg1, cg2), 0)

  reset_caugi_registry()
})
test_that("HD: symmetrical node relations work with hd", {
  cg1 <- caugi(A %---% B)
  cg2 <- caugi(B %---% A)

  expect_equal(hd(cg1, cg2), 0)
})

test_that("HD: same graphs but written in different ways work with hd", {
  reset_caugi_registry()

  register_caugi_edge("<--", "arrow", "tail", "directed", FALSE)
  cg1 <- caugi(A %-->% B, B %-->% C)
  cg2 <- caugi(C %<--% B, B %<--% A)

  expect_equal(hd(cg1, cg2), 0)
  reset_caugi_registry()
})

test_that("HD: does not depend on node declaration order (#323)", {
  dag <- caugi(A %-->% B, B %-->% C)
  pdag <- caugi(A %---% B, B %-->% C)
  pdag2 <- caugi(B %---% A, B %-->% C)

  # Same skeleton, so HD must be 0 regardless of how the edge is written.
  expect_equal(hd(dag, pdag), 0)
  expect_equal(hd(dag, pdag2), 0)
  expect_equal(hd(dag, pdag), hd(dag, pdag2))
})
