# `==` compares graph content, so a symmetric edge must be an unordered pair.
#
# Regression test. `==` previously compared the `from`/`to` columns literally,
# so `A --- B` and `B --- A` -- the same edge -- came out unequal. Any
# comparison of a graph against one a transformation produced was therefore
# sensitive to the declared node order alone.

test_that("symmetric edges compare as unordered pairs", {
  expect_true(caugi(A %---% B, class = "UG") == caugi(B %---% A, class = "UG"))
  expect_true(
    caugi(A %<->% B, class = "ADMG") == caugi(B %<->% A, class = "ADMG")
  )
  expect_true(
    caugi(A %o-o% B, class = "UNKNOWN") == caugi(B %o-o% A, class = "UNKNOWN")
  )
})

test_that("asymmetric edges stay direction-sensitive", {
  expect_false(
    caugi(A %-->% B, class = "DAG") == caugi(B %-->% A, class = "DAG")
  )
  # `o->` is asymmetric: the circle and the arrowhead sit on named ends.
  expect_false(
    caugi(A %o->% B, class = "UNKNOWN") == caugi(B %o->% A, class = "UNKNOWN")
  )
})

test_that("edge row order is ignored", {
  expect_true(
    caugi(A %-->% B, B %-->% C, class = "DAG") ==
      caugi(B %-->% C, A %-->% B, class = "DAG")
  )
  # Mixed symmetric and asymmetric, declared in a different order.
  expect_true(
    caugi(A %-->% B, B %<->% C, class = "ADMG") ==
      caugi(C %<->% B, A %-->% B, class = "ADMG")
  )
})

test_that("a custom symmetric edge is canonicalised too", {
  # Symmetry is read from the registry, not a hard-coded glyph list.
  reset_caugi_registry()
  on.exit(reset_caugi_registry(), add = TRUE)
  register_caugi_edge("*-*", "other", "other", "undirected", symmetric = TRUE)

  expect_true(
    caugi(A %*-*% B, class = "UNKNOWN") == caugi(B %*-*% A, class = "UNKNOWN")
  )
})

test_that("genuinely different graphs still compare unequal", {
  expect_false(caugi(A %---% B, class = "UG") == caugi(A %---% C, class = "UG"))
  expect_false(
    caugi(A %---% B, class = "UG") == caugi(A %-->% B, class = "DAG")
  )
})
