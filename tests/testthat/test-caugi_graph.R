# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── caugi graph tests ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Length ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi graph length is correct", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %--o% E,
    E %o->% F,
    F %o-o% A
  )
  expect_equal(length(cg), 6)

  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D
  )
  expect_equal(length(cg), 4)

  cg <- caugi(
    A %---% B
  )
  expect_equal(length(cg), 2)

  cg <- caugi()
  expect_equal(length(cg), 0)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Initialization ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi graph generation works as expected", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %--o% E,
    E %o->% F,
    F %o-o% A
  )
  expect_s7_class(cg, caugi)
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
  cg <- caugi()
  expect_s7_class(cg, caugi)
  expect_equal(length(cg), 0)
  expect_equal(nrow(cg@edges), 0)
  expect_equal(length(cg), 0)
})


test_that("building graph with invalid class results in error", {
  expect_error(
    caugi(
      A %-->% B,
      B %---% C,
      class = "INVALID"
    )
  )
})

test_that("building a graph with duplicates will deduplicate on initial call", {
  cg <- caugi(
    A %-->% B,
    A %-->% B,
    B %---% C,
    B %---% C,
    class = "PDAG"
  )

  cg_equiv <- caugi(
    A %-->% B,
    B %---% C,
    class = "PDAG"
  )
  expect_equal(cg, cg_equiv)
})

test_that("expression and isolated nodes in nodes", {
  cg <- caugi(
    A %-->% B,
    nodes = c("C", "D", "E")
  )
  expect_s7_class(cg, caugi)
  expect_equal(nodes(cg)$name, c("A", "B", "C", "D", "E"))
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Simple / non-simple ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("building graph with simple = FALSE needs class = UNKNOWN", {
  expect_error(
    caugi(
      A %-->% B,
      B %---% C,
      class = "DAG",
      simple = FALSE
    )
  )
  expect_error(
    caugi(
      A %-->% B,
      B %---% C,
      class = "PDAG",
      simple = FALSE
    )
  )
  expect_s7_class(
    caugi(
      A %-->% B,
      B %---% C,
      class = "UNKNOWN",
      simple = FALSE
    ),
    caugi
  )
})

test_that("non-simple graphs allows self loops and parallel edges", {
  expect_s7_class(
    caugi(
      A %-->% A,
      B %---% C,
      class = "UNKNOWN",
      simple = FALSE
    ),
    caugi
  )
  expect_s7_class(
    caugi(
      A %-->% B,
      A %<->% B,
      class = "UNKNOWN",
      simple = FALSE
    ),
    caugi
  )

  expect_s7_class(
    caugi(
      A %-->% B,
      A %o->% A,
      class = "UNKNOWN",
      simple = FALSE
    ),
    caugi
  )
})

test_that("building graph with simple = TRUE disallows parallel edges", {
  expect_error(
    caugi(
      A %-->% B,
      A %---% B,
      class = "UNKNOWN",
      simple = TRUE
    )
  )
  expect_s7_class(
    caugi(
      A %-->% B,
      B %---% C,
      class = "UNKNOWN",
      simple = TRUE
    ),
    caugi
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── DAG tests ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("building DAG with non-directed edges results in error", {
  expect_error(
    caugi(
      A %-->% B,
      B %---% C,
      class = "DAG"
    )
  )
  expect_error(
    caugi(
      A %-->% B,
      B %o->% C,
      class = "DAG"
    )
  )
})

test_that("building DAG with cycle results in error", {
  expect_error(
    caugi(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "DAG"
    )
  )
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg |> add_edge(B %-->% A) |> build()
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── PDAG tests ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("building PDAG with directed cycle results in error", {
  expect_error(
    caugi(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "PDAG"
    )
  )
  cg <- caugi(A %-->% B, class = "PDAG")
  expect_error(
    cg |> add_edge(B %-->% A) |> build()
  )
})

test_that("building PDAG with bidirected edges results in error", {
  expect_error(
    caugi(
      A %-->% B,
      B %<->% C,
      class = "PDAG"
    )
  )
  expect_error(
    caugi(
      A %-->% B,
      B %o-o% C,
      class = "PDAG"
    )
  )
  cg <- caugi(A %-->% B, class = "PDAG")
  expect_error(
    cg |> add_edge(B %o->% C) |> build()
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── AUTO tests ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("AUTO class picks the correct class", {
  cg <- caugi(A %-->% B, class = "AUTO")
  expect_equal(cg@graph_class, "DAG")
  cg <- caugi(A %---% B, class = "AUTO")
  expect_equal(cg@graph_class, "UG")
  cg <- caugi(A %<->% B, class = "AUTO")
  expect_equal(cg@graph_class, "ADMG")
  cg <- caugi(A %o->% B, class = "AUTO")
  expect_equal(cg@graph_class, "UNKNOWN")
  cg <- caugi(A %-->% B %---% C, class = "AUTO")
  expect_equal(cg@graph_class, "PDAG")
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────── Standard evaluation input ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi builds from parallel vectors", {
  cg_vec <- caugi(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to = c("B", "C", "D")
  )

  expect_s7_class(cg_vec, caugi)
  expect_equal(sort(cg_vec@nodes$name), sort(c("A", "B", "C", "D")))
  expect_equal(nrow(cg_vec@edges), 3)
  expect_true(all(c("from", "edge", "to") %in% names(cg_vec@edges)))

  cg_expr <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D
  )
  expect_equal(cg_vec, cg_expr)
})

test_that("caugi forbids mixing ... with from/edge/to", {
  expect_error(
    caugi(
      A %-->% B,
      from = "C",
      edge = "-->",
      to = "D"
    ),
    "Provide edges via infix expressions"
  )
})

test_that("caugi requires from, edge, to all present and equal length", {
  # missing one
  expect_error(
    caugi(from = "A", edge = "-->"),
    "`from`, `edge`, and `to` must all be provided."
  )

  # length mismatch
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = "C"
    ),
    "`from`, `edge`, and `to` must be equal length."
  )
})

test_that("caugi with empty vectors yields empty graph", {
  cg <- caugi(from = character(), edge = character(), to = character())
  expect_s7_class(cg, caugi)
  expect_equal(length(cg), 0)
  expect_equal(nrow(cg@edges), 0)
  expect_equal(nrow(cg@nodes), 0)
})

test_that("caugi(vector mode) gets the same result as in with DSL", {
  cg1 <- caugi(
    from = c("A"),
    edge = c("-->"),
    to = c("B")
  )
  cg2 <- caugi(A %-->% B)
  expect_equal(cg1, cg2)
})

test_that("caugi(vector mode) respects class and simple rules", {
  # valid PDAG
  expect_s7_class(
    caugi(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c("B", "C"),
      class = "PDAG"
    ),
    caugi
  )

  # invalid DAG due to non-directed edge
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c("B", "C"),
      class = "DAG"
    )
  )

  # simple = TRUE disallows parallel edges under UNKNOWN
  expect_error(
    caugi(
      from = c("A", "A"),
      edge = c("-->", "<->"),
      to = c("B", "B"),
      class = "UNKNOWN",
      simple = TRUE
    )
  )
})

test_that("caugi(vector mode) works with isolated nodes", {
  cg_vec_1 <- caugi(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to = c("B", "C", "D"),
    nodes = c("A", "B", "C", "D", "E", "F")
  )
  cg_vec_2 <- caugi(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to = c("B", "C", "D"),
    nodes = c("E", "F")
  )
  expect_equal(cg_vec_1, cg_vec_2)
})

test_that("caugi preserves node order from nodes parameter", {
  # When nodes parameter is provided, its order should be preserved
  # even when edges reference nodes in different order
  cg <- caugi(
    from = c("V3", "V7", "V2"),
    edge = c("-->", "-->", "-->"),
    to = c("V1", "V9", "V5"),
    nodes = paste0("V", 1:10),
    class = "DAG"
  )

  # Node order should match the provided nodes parameter
  expect_equal(V(cg)$name, paste0("V", 1:10))

  # Edges should still be present and correct
  expect_equal(nrow(edges(cg)), 3)
})

test_that("edges_df input works", {
  edges_df <- data.frame(
    from = c("A", "B", "C"),
    edge = c("-->", "---", "<->"),
    to = c("B", "C", "D")
  )

  cg_df <- caugi(edges_df = edges_df)

  cg_expr <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D
  )

  expect_equal(cg_df, cg_expr)
})

test_that("edges_df input works for empty graph", {
  edges_df <- data.frame(
    from = character(),
    edge = character(),
    to = character()
  )

  cg_df <- caugi(edges_df = edges_df)

  cg_empty <- caugi()

  expect_equal(cg_df, cg_empty)
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Errors and warnings ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("caugi errors with trailing commas", {
  expect_error(
    caugi(
      A %-->% B,
      B %---% C,
    ),
    "Argument 3 is missing"
  )
})

test_that("caugi warns when build = TRUE for empty graph", {
  expect_warning(
    caugi(build = TRUE),
    "No edges or nodes provided; graph will not be built."
  )
})

test_that("caugi with wrong node input errors", {
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c("B", "C"),
      nodes = list("D", "E")
    ),
    "`nodes` must be a character vector"
  )
})

test_that("from, edge, to vectors are not characters", {
  expect_error(
    caugi(
      from = c(1, 2),
      edge = c("-->", "---"),
      to = c("B", "C")
    ),
    "`from`, `edge`, and `to` must all be character vectors."
  )
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c(1, 2),
      to = c("B", "C")
    ),
    "`from`, `edge`, and `to` must all be character vectors."
  )
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c(1, 2)
    ),
    "`from`, `edge`, and `to` must all be character vectors."
  )
})

test_that("caugi with both edges df input and vectors from, edge, to errors", {
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c("-->", "---"),
      to = c("B", "C"),
      edges_df = data.frame(
        from = c("C"),
        edge = c("<->"),
        to = c("D")
      )
    ),
    "Provide edges via `edges_df` or via `from`, `edge`, `to`, but not both"
  )
})

test_that("caugi with both edges df and expressions errors", {
  expect_error(
    caugi(
      A %-->% B,
      edges_df = data.frame(
        from = c("C"),
        edge = c("<->"),
        to = c("D")
      )
    ),
    "Provide edges via infix expressions in `...` or via `edges_df`"
  )
})

test_that("faulty edges df throws errors", {
  expect_error(
    caugi(
      edges_df = data.frame(
        from = c("A", "B"),
        edge = c("-->", "---")
      )
    ),
    "`edges_df` must contain columns: from, edge, to"
  )
})

test_that("faulty vec input throws error", {
  expect_error(
    caugi(
      from = c("A", "B"),
      edge = c(1, 2),
      to = c("B", "C")
    ),
    "`from`, `edge`, and `to` must all be character vectors."
  )
})

test_that("edges df input is not a data.frame or data.table", {
  expect_error(
    caugi(
      edges_df = list(
        from = c("A", "B"),
        edge = c("-->", "---"),
        to = c("B", "C")
      )
    ),
    "`edges_df` must be a data.frame or data.table."
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── .view_to_caugi ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".view_to_caugi works as expected", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D
  )

  cg2 <- .view_to_caugi(cg@ptr)
  expect_s7_class(cg2, caugi)
  expect_equal(cg, cg2)
})

test_that(".view_to_caugi fails on NULL ptr", {
  expect_error(
    .view_to_caugi(NULL),
    "ptr is NULL"
  )
})

test_that(".view_to_caugi fails on faulty node_names", {
  cg <- caugi(
    A %-->% B
  )
  expect_error(
    .view_to_caugi(cg@ptr, node_names = c("A")),
    "length"
  )
})

test_that(".view_to_caugi works for empty cg", {
  cg <- caugi(A, B, build = TRUE)
  expect_equal(cg, .view_to_caugi(cg@ptr))
})


# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── UG tests ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("UG graph can be created with undirected edges only", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% D,
    class = "UG"
  )
  expect_s7_class(cg, caugi)
  expect_equal(cg@graph_class, "UG")
  expect_equal(nrow(cg@nodes), 4)
  expect_equal(nrow(cg@edges), 3)
})

test_that("UG graph rejects directed edges", {
  expect_error(
    caugi(
      A %-->% B,
      class = "UG"
    ),
    "undirected"
  )
})

test_that("UG graph rejects bidirected edges", {
  expect_error(
    caugi(
      A %<->% B,
      class = "UG"
    )
  )
})

test_that("UG graph rejects partially directed edges", {
  expect_error(
    caugi(
      A %o->% B,
      class = "UG"
    )
  )
})

test_that("UG graph rejects partially undirected edges", {
  expect_error(
    caugi(
      A %--o% B,
      class = "UG"
    )
  )
})

test_that("UG graph neighbors_of query works", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    B %---% D,
    class = "UG"
  )
  expect_equal(neighbors(cg, "A"), "B")
  expect_equal(sort(neighbors(cg, "B")), c("A", "C", "D"))
  expect_equal(neighbors(cg, "C"), "B")
  expect_equal(neighbors(cg, "D"), "B")
})

test_that("UG graph parents_of and children_of are not defined", {
  cg <- caugi(
    A %---% B,
    class = "UG"
  )
  expect_error(parents(cg, "A"), "not defined for UG")
  expect_error(children(cg, "B"), "not defined for UG")
})

test_that("UG graph ancestors_of and descendants_of are not defined", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )
  expect_error(ancestors(cg, "B"), "not defined for UG")
  expect_error(descendants(cg, "B"), "not defined for UG")
})

test_that("UG graph markov_blanket_of returns neighbors", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    B %---% D,
    class = "UG"
  )
  expect_equal(sort(markov_blanket(cg, "B")), c("A", "C", "D"))
  expect_equal(markov_blanket(cg, "A"), "B")
})

test_that("UG graph exogenous function works", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    nodes = c("A", "B", "C", "D", "E"),
    class = "UG"
  )
  expect_equal(sort(exogenous(cg)), c("D", "E"))
})

test_that("UG graph with only isolated nodes", {
  cg <- caugi(
    nodes = c("A", "B", "C"),
    class = "UG"
  )
  expect_equal(nrow(cg@edges), 0)
  expect_equal(nrow(cg@nodes), 3)
  expect_equal(sort(exogenous(cg)), c("A", "B", "C"))
})

test_that("UG graph can build complex structures", {
  # Create a triangle (cycle)
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "UG"
  )
  expect_equal(nrow(cg@nodes), 3)
  expect_equal(nrow(cg@edges), 3)

  # Each node should have 2 neighbors
  expect_length(neighbors(cg, "A"), 2)
  expect_length(neighbors(cg, "B"), 2)
  expect_length(neighbors(cg, "C"), 2)
})

test_that("UG graph can create a path", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% D,
    D %---% E,
    class = "UG"
  )
  expect_equal(neighbors(cg, "A"), "B")
  expect_equal(sort(neighbors(cg, "B")), c("A", "C"))
  expect_equal(sort(neighbors(cg, "C")), c("B", "D"))
  expect_equal(sort(neighbors(cg, "D")), c("C", "E"))
  expect_equal(neighbors(cg, "E"), "D")
})

test_that("UG graph can create a star", {
  cg <- caugi(
    Center %---% A + B + C + D,
    class = "UG"
  )
  expect_equal(sort(neighbors(cg, "Center")), c("A", "B", "C", "D"))
  expect_equal(neighbors(cg, "A"), "Center")
  expect_equal(neighbors(cg, "B"), "Center")
  expect_equal(neighbors(cg, "C"), "Center")
  expect_equal(neighbors(cg, "D"), "Center")
})

test_that("UG graph length returns number of nodes", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )
  expect_equal(length(cg), 3)

  cg_empty <- caugi(class = "UG")
  expect_equal(length(cg_empty), 0)
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Property Setters ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("nodes property setter is read-only", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg@nodes <- data.frame(name = c("X", "Y")),
    "nodes is read-only"
  )
})

test_that("edges property setter is read-only", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg@edges <- data.frame(from = "X", to = "Y", edge = "-->"),
    "edges.*is read-only"
  )
})

test_that("ptr property setter is read-only", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg@ptr <- NULL,
    "ptr.*is read-only"
  )
})

test_that("built property setter is read-only", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg@built <- TRUE,
    "built.*is read-only"
  )
})

test_that("graph_class property setter is read-only", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg@graph_class <- "PDAG",
    "graph_class.*is read-only"
  )
})

test_that("name_index_map property setter is read-only", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    cg@name_index_map <- list(),
    "name_index_map.*is read-only"
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Validation ──────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("validator catches simple=FALSE for non-ADMG/AG classes", {
  expect_error(
    caugi(A %-->% B, class = "DAG", simple = FALSE),
    "If simple = FALSE, class must be"
  )
  expect_error(
    caugi(A %-->% B, class = "PDAG", simple = FALSE),
    "If simple = FALSE, class must be"
  )
})

test_that("ADMG and AG allow simple=FALSE", {
  expect_s7_class(caugi(A %-->% B, class = "ADMG", simple = FALSE), caugi)
  expect_s7_class(caugi(A %-->% B, class = "AG", simple = FALSE), caugi)
  expect_s7_class(caugi(A %-->% B, class = "UNKNOWN", simple = FALSE), caugi)
})
