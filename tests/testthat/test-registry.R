# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Registry tests ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Initialization ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi_registry initializes once and loads builtins", {
  reset_caugi_registry()
  r1 <- caugi_registry()
  r2 <- caugi_registry()
  expect_identical(r1, r2)
  expect_equal(edge_registry_len(r1), 6L)

  reset_caugi_registry()
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── Registration ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("register_caugi_edge validates class/symmetric", {
  reset_caugi_registry()
  expect_error(register_caugi_edge("-->", "tail", "arrow", "directed", TRUE))
  expect_error(register_caugi_edge("---", "tail", "tail", "undirected", FALSE))

  reset_caugi_registry()
})

test_that("register_caugi_edge registers operator and glyph map", {
  reset_caugi_registry()
  reg <- caugi_registry()
  sucess <- register_caugi_edge("--<", "tail", "other", "directed", FALSE)
  expect_true(sucess)
  edge_ops_get <- getFromNamespace(".edge_ops_get", "caugi")
  glyph_map_get <- getFromNamespace(".glyph_map_get", "caugi")
  op <- "%--<%"
  expect_true(op %in% edge_ops_get())
  expect_equal(glyph_map_get()[[op]], "--<")
  expect_gt(edge_registry_code_of(reg, "--<"), 0L)

  reset_caugi_registry()
})

test_that("duplicate glyph triggers operator registration error on second call", {
  reset_caugi_registry()
  register_caugi_edge("o-<", "circle", "arrow", "directed", FALSE)
  expect_error(
    register_caugi_edge("o-<", "circle", "arrow", "directed", FALSE),
    "already registered"
  )

  reset_caugi_registry()
})


test_that("glyph validation", {
  reset_caugi_registry()
  expect_error(
    register_caugi_edge("----", "tail", "arrow", "directed", FALSE),
    "length 3"
  )
  expect_error(
    register_caugi_edge("%->", "tail", "arrow", "directed", FALSE),
    "must not contain '%'"
  )
  expect_error(
    register_caugi_edge(c("-->", "<--"), "tail", "arrow", "directed", FALSE),
    "single string"
  )

  reset_caugi_registry()
})


# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Sealing ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("seal_caugi_registry prevents further registrations", {
  reset_caugi_registry()
  seal_caugi_registry()
  expect_error(
    register_caugi_edge("x-x", "other", "other", "undirected", TRUE),
    "sealed|Sealed"
  )

  reset_caugi_registry()
})

test_that("reset_caugi_registry clears ops and glyph map", {
  reset_caugi_registry()
  register_caugi_edge("-o>", "tail", "arrow", "partially_directed", FALSE)
  edge_ops_get <- getFromNamespace(".edge_ops_get", "caugi")
  glyph_map_get <- getFromNamespace(".glyph_map_get", "caugi")
  expect_true("%-o>%" %in% edge_ops_get())
  reset_caugi_registry()
  expect_false("%-o>%" %in% getFromNamespace(".edge_ops_get", "caugi")())
  m <- getFromNamespace(".glyph_map_get", "caugi")()
  expect_false("%-o>%" %in% names(m))

  reset_caugi_registry()
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Resetting ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("reset_caugi_registry does not allow overwriting builtin edges", {
  reset_caugi_registry()
  expect_error(
    register_caugi_edge("-->", "tail", "arrow", "undirected", TRUE),
    "already registered"
  )

  reset_caugi_registry()
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── Behavior of new edges ─────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("reverse edge, <--, behaves correctly, when initalized in a cg", {
  reset_caugi_registry()
  register_caugi_edge("<--", "arrow", "tail", "directed", FALSE)
  cg <- caugi(A %-->% B, B %<--% C, class = "DAG")
  expect_identical(parents_of_ptr(cg@ptr, 0L), list(integer(0)))
  expect_identical(children_of_ptr(cg@ptr, 0L), list(1L))
  expect_identical(parents_of_ptr(cg@ptr, 1L), list(c(0L, 2L)))
  expect_identical(children_of_ptr(cg@ptr, 1L), list(integer(0)))
  expect_identical(parents_of_ptr(cg@ptr, 2L), list(integer(0)))
  expect_identical(children_of_ptr(cg@ptr, 2L), list(1L))

  reset_caugi_registry()
})

test_that("reverse edge, <--, cannot create cycles", {
  reset_caugi_registry()
  register_caugi_edge("<--", "arrow", "tail", "directed", FALSE)
  expect_error(caugi(A %-->% B, B %-->% C, A %<--% C, class = "DAG"))
  reset_caugi_registry()
})

test_that("new edge type, x-x, cannot create duplicate or parallel edges", {
  reset_caugi_registry()
  register_caugi_edge("x-x", "other", "other", "undirected", TRUE)

  # duplicate edges
  expect_error(caugi(A %x-x% B, B %x-x% A, class = "Unknown"))

  # self loop
  expect_error(caugi(A %x-x% A, class = "Unknown"))

  # parallel edges
  expect_error(caugi(A %---% B, A %x-x% B, class = "Unknown"))

  reset_caugi_registry()
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Is edge symmetric? ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("is_edge_symmetric errors with non registered glyph", {
  reset_caugi_registry()
  expect_error(is_edge_symmetric(":o)"), "not registered")
  reset_caugi_registry()
})

test_that("is_edge_symmetric works for registered edges", {
  reset_caugi_registry()
  expect_error(is_edge_symmetric("-->"))
  expect_true(is_edge_symmetric("---"))
  reset_caugi_registry()
})
