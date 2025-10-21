# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── caugi graph tests ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Length ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi graph length is correct", {
  cg <- caugi_graph(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %--o% E,
    E %o->% F,
    F %o-o% A
  )
  expect_equal(length(cg), 6)

  cg <- caugi_graph(
    A %-->% B,
    B %-->% C,
    C %-->% D
  )
  expect_equal(length(cg), 4)

  cg <- caugi_graph(
    A %---% B
  )
  expect_equal(length(cg), 2)

  cg <- caugi_graph()
  expect_equal(length(cg), 0)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Initialization ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi graph generation works as expected", {
  cg <- caugi_graph(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %--o% E,
    E %o->% F,
    F %o-o% A
  )
  expect_s7_class(cg, caugi_graph)
  expect_equal(nrow(cg@nodes), 6)
  expect_equal(nrow(cg@edges), 6)
  expect_true(all(c("from", "edge", "to") %in% names(cg@edges)))
  expect_true(all(c("name") %in% names(cg@nodes)))
  expect_equal(sort(cg@nodes$name), sort(LETTERS[1:6]))
  expect_equal(
    sort(cg@edges$edge),
    sort(c("o->", "--o", "o-o", "-->", "<->", "---"))
  )
})

test_that("empty caugi graph initialization works", {
  cg <- caugi_graph()
  expect_s7_class(cg, caugi_graph)
  expect_equal(length(cg), 0)
  expect_equal(nrow(cg@edges), 0)
  expect_equal(length(cg), 0)
})


test_that("building graph with invalid class results in error", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "INVALID"
    )
  )
})

test_that("building a graph with duplicates will deduplicate on initial call", {
  cg <- caugi_graph(
    A %-->% B,
    A %-->% B,
    B %---% C,
    B %---% C,
    class = "PDAG"
  )

  cg_equiv <- caugi_graph(
    A %-->% B,
    B %---% C,
    class = "PDAG"
  )
  expect_equal(cg, cg_equiv)
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Simple / non-simple ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("building graph with simple = FALSE needs class = Unknown", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "DAG",
      simple = FALSE
    )
  )
  expect_error(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "PDAG",
      simple = FALSE
    )
  )
  expect_s7_class(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "Unknown",
      simple = FALSE
    ),
    caugi_graph
  )
})

test_that("non-simple graphs allows self loops and parallel edges", {
  expect_s7_class(
    caugi_graph(
      A %-->% A,
      B %---% C,
      class = "Unknown",
      simple = FALSE
    ),
    caugi_graph
  )
  expect_s7_class(
    caugi_graph(
      A %-->% B,
      A %<->% B,
      class = "Unknown",
      simple = FALSE
    ),
    caugi_graph
  )

  expect_s7_class(
    caugi_graph(
      A %-->% B,
      A %o->% A,
      class = "Unknown",
      simple = FALSE
    ),
    caugi_graph
  )
})

test_that("building graph with simple = TRUE disallows parallel edges", {
  expect_error(
    caugi_graph(
      A %-->% B,
      A %---% B,
      class = "Unknown",
      simple = TRUE
    )
  )
  expect_s7_class(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "Unknown",
      simple = TRUE
    ),
    caugi_graph
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── DAG tests ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("building DAG with non-directed edges results in error", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "DAG"
    )
  )
  expect_error(
    caugi_graph(
      A %-->% B,
      B %o->% C,
      class = "DAG"
    )
  )
})

test_that("building DAG with cycle results in error", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "DAG"
    )
  )
  cg <- caugi_graph(A %-->% B, class = "DAG")
  expect_error(
    cg |> add_edge(B %-->% A) |> build()
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── PDAG tests ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("building PDAG with directed cycle results in error", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "PDAG"
    )
  )
  cg <- caugi_graph(A %-->% B, class = "PDAG")
  expect_error(
    cg |> add_edge(B %-->% A) |> build()
  )
})

test_that("building PDAG with bidirected edges results in error", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %<->% C,
      class = "PDAG"
    )
  )
  expect_error(
    caugi_graph(
      A %-->% B,
      B %o-o% C,
      class = "PDAG"
    )
  )
  cg <- caugi_graph(A %-->% B, class = "PDAG")
  expect_error(
    cg |> add_edge(B %o->% C) |> build()
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────── Standard evaluation input ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi_graph builds from parallel vectors", {
  cg_vec <- caugi_graph(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to   = c("B", "C", "D")
  )

  expect_s7_class(cg_vec, caugi_graph)
  expect_equal(sort(cg_vec@nodes$name), sort(c("A", "B", "C", "D")))
  expect_equal(nrow(cg_vec@edges), 3)
  expect_true(all(c("from", "edge", "to") %in% names(cg_vec@edges)))

  cg_expr <- caugi_graph(
    A %-->% B,
    B %---% C,
    C %<->% D
  )
  expect_equal(cg_vec, cg_expr)
})

test_that("caugi_graph forbids mixing ... with from/edge/to", {
  expect_error(
    caugi_graph(
      A %-->% B,
      from = "C", edge = "-->", to = "D"
    ),
    "Provide edges via infix expressions"
  )
})

test_that("caugi_graph requires from, edge, to all present and equal length", {
  # missing one
  expect_error(
    caugi_graph(from = "A", edge = "-->"),
    "`from`, `edge`, `to` must all be supplied"
  )

  # length mismatch
  expect_error(
    caugi_graph(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to   = "C"
    ),
    "`from`, `edge`, `to` must be equal length"
  )
})

test_that("caugi_graph with empty vectors yields empty graph", {
  cg <- caugi_graph(from = character(), edge = character(), to = character())
  expect_s7_class(cg, caugi_graph)
  expect_equal(length(cg), 0)
  expect_equal(nrow(cg@edges), 0)
  expect_equal(nrow(cg@nodes), 0)
})

test_that("caugi_graph(vector mode) gets the same result as in with DSL", {
  cg1 <- caugi_graph(
    from = c("A"),
    edge = c("-->"),
    to   = c("B")
  )
  cg2 <- caugi_graph(A %-->% B)
  expect_equal(cg1, cg2)
})

test_that("caugi_graph(vector mode) respects class and simple rules", {
  # valid PDAG
  expect_s7_class(
    caugi_graph(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c("B", "C"),
      class = "PDAG"
    ),
    caugi_graph
  )

  # invalid DAG due to non-directed edge
  expect_error(
    caugi_graph(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c("B", "C"),
      class = "DAG"
    )
  )

  # simple = TRUE disallows parallel edges under Unknown
  expect_error(
    caugi_graph(
      from = c("A", "A"),
      edge = c("-->", "<->"),
      to = c("B", "B"),
      class = "Unknown",
      simple = TRUE
    )
  )
})

test_that("caugi_graph(vector mode) works with isolated nodes", {
  cg_vec_1 <- caugi_graph(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to = c("B", "C", "D"),
    nodes = c("A", "B", "C", "D", "E", "F")
  )
  cg_vec_2 <- caugi_graph(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to = c("B", "C", "D"),
    nodes = c("E", "F")
  )
  expect_equal(cg_vec_1, cg_vec_2)
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────── ADMG ─────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("ADMG graph accepts directed and bidirected edges", {
  cg <- caugi_graph(
    A %-->% B,
    B %<->% C,
    A %-->% C,
    class = "ADMG"
  )
  expect_s7_class(cg, caugi_graph)
  expect_equal(cg@graph_class, "ADMG")
  expect_equal(nrow(cg@nodes), 3)
  expect_equal(nrow(cg@edges), 3)
})

test_that("ADMG graph rejects undirected edges", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %---% C,
      class = "ADMG"
    ),
    "cannot contain undirected"
  )
})

test_that("ADMG graph rejects partial edges", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %o->% C,
      class = "ADMG"
    ),
    "cannot contain.*partial"
  )
})

test_that("ADMG graph rejects directed cycles", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "ADMG"
    ),
    "cycle"
  )
})

test_that("ADMG graph allows bidirected cycles", {
  cg <- caugi_graph(
    A %<->% B,
    B %<->% C,
    C %<->% A,
    class = "ADMG"
  )
  expect_s7_class(cg, caugi_graph)
  expect_equal(nrow(cg@edges), 3)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Errors ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi_graph errors with trailing commas", {
  expect_error(
    caugi_graph(
      A %-->% B,
      B %---% C,
    ),
    "Argument 3 is missing"
  )
})
