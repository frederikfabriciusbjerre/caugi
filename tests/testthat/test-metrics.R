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
