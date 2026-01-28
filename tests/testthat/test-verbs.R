# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── Verbs tests ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Building ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("build() generic dispatches", {
  expect_error(build(1), "Can't find method")
})

test_that("build.caugi builds with and without edges", {
  cg <- caugi()
  cg <- add_nodes(cg, name = c("A", "B"))
  cg0 <- build(cg) # no edges
  expect_true(cg0@built)
  expect_false(is.null(cg0@ptr))

  cg <- add_edges(cg, from = "A", edge = "-->", to = "B")
  cg1 <- build(cg) # with edges
  expect_true(cg1@built)
  expect_equal(cg1@nodes$name, c("A", "B"))
  expect_equal(
    cg1@edges,
    data.table::data.table(from = "A", edge = "-->", to = "B")
  )

  expect_identical(build(cg1), cg1) # identical if built
})

test_that("build() errors when breaking simple graph assumptions", {
  cg <- caugi()
  cg <- add_edges(
    cg,
    from = c("A", "A"),
    edge = c("o->", "-->"),
    to = c("B", "B")
  )
  expect_error(build(cg), "Parallel edges not allowed")
  cg <- caugi()
  cg <- add_edges(
    cg,
    from = c("A", "A"),
    edge = c("-->", "<->"),
    to = c("B", "A")
  )
  expect_error(build(cg), "Self-loops not allowed")
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Edges ─────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("add_edges validates inputs and updates graph", {
  cg <- caugi()
  expect_identical(add_edges(cg), cg)

  expect_error(
    add_edges(cg, A %-->% B, from = "A", edge = "-->", to = "B"),
    "Provide expressions"
  )
  expect_error(
    add_edges(cg, from = "A"),
    "`from`, `edge`, `to` must all be supplied"
  )
  expect_error(
    add_edges(cg, from = c("A", "B"), edge = "-->", to = "B"),
    "equal length"
  )

  cg1 <- add_edges(cg, from = "A", edge = "-->", to = "B")
  expect_false(cg1@built)
  expect_setequal(cg1@nodes$name, c("A", "B"))
  expect_equal(
    cg1@edges,
    data.table::data.table(from = "A", edge = "-->", to = "B")
  )

  cg2 <- add_edges(
    cg1,
    from = c("A", "A"),
    edge = c("-->", "-->"),
    to = c("B", "B")
  )
  expect_equal(nrow(cg2@edges), 1L)
})

test_that("add_edges makes built = FALSE, build(cg) makes it TRUE (back and forth)", {
  cg <- caugi()

  cg1 <- add_edges(cg, from = "A", edge = "-->", to = "B")
  expect_false(cg1@built)

  cg1_built <- build(cg1)
  expect_true(cg1_built@built)

  cg2 <- add_edges(
    cg1,
    from = c("A", "A"),
    edge = c("-->", "-->"),
    to = c("B", "B")
  )
  expect_false(cg2@built)
})

test_that("add_edges expression path works", {
  cg <- caugi()
  cg <- add_edges(
    cg,
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %--o% E,
    E %o->% F,
    F %o-o% A
  )
  expect_false(cg@built)
  expect_setequal(cg@nodes$name, c("A", "B", "C", "D", "E", "F"))
  expect_equal(nrow(cg@edges), 6L)
  expect_true(all(c("from", "edge", "to") %in% names(cg@edges)))
  expect_equal(sort(cg@nodes$name), sort(LETTERS[1:6]))
  expect_equal(
    sort(cg@edges$edge),
    sort(c("o->", "--o", "o-o", "-->", "<->", "---"))
  )
})

test_that("add_edges expression path (DSL) works (also some + notation)", {
  cg <- caugi()
  cg <- add_nodes(cg, A + B)
  cg <- add_edges(cg, A %-->% B + C)
  expect_setequal(cg@nodes$name, c("A", "B", "C"))
  expect_equal(
    cg@edges,
    data.table::data.table(
      from = "A",
      edge = c("-->", "-->"),
      to = c("B", "C")
    )
  )
})

test_that("remove_edges works and keeps other edges", {
  cg <- caugi()
  cg <- add_edges(
    cg,
    from = c("A", "A"),
    edge = c("-->", "-->"),
    to = c("B", "C")
  )
  expect_identical(remove_edges(cg), cg) # no-op
  expect_error(
    remove_edges(cg, A %-->% B, from = "A", edge = "-->", to = "B"),
    "Provide expressions"
  )

  cg1 <- remove_edges(cg, from = "A", edge = "-->", to = "B")
  expect_false(cg1@built)
  expect_equal(
    cg1@edges,
    data.table::data.table(from = "A", edge = "-->", to = "C")
  )
})

test_that("set_edges replaces any existing edges for pairs", {
  cg <- caugi()
  cg <- add_edges(
    cg,
    from = c("A", "A"),
    edge = c("o->", "-->"),
    to = c("B", "B")
  )
  cg1 <- set_edges(cg, from = "A", edge = "<->", to = "B")
  expect_false(cg1@built)
  expect_equal(
    cg1@edges,
    data.table::data.table(from = "A", edge = "<->", to = "B")
  )
})

test_that("set_edges errors whwn both vector and expr paths are given", {
  cg <- caugi()
  cg <- add_edges(
    cg,
    from = c("A", "A"),
    edge = c("o->", "-->"),
    to = c("B", "B")
  )
  expect_error(
    set_edges(cg, A %-->% B, from = "A", edge = "<->", to = "B"),
    "Provide expressions"
  )
})

test_that("set_edges returns cg if nothing given", {
  cg <- caugi(A %-->% B, B %-->% C)
  cg2 <- set_edges(cg)

  expect_equal(cg, cg2)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── Nodes ─────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("add_nodes, remove_nodes cover vector and expr paths", {
  cg <- caugi()
  expect_identical(add_nodes(cg), cg)

  cg1 <- add_nodes(cg, name = c("A", "B"))
  expect_false(cg1@built)
  expect_setequal(cg1@nodes$name, c("A", "B"))

  cg2 <- add_nodes(caugi(), A + B + C)
  expect_setequal(cg2@nodes$name, c("A", "B", "C"))

  cg3 <- add_edges(cg1, from = "A", edge = "-->", to = "B")
  cg4 <- remove_nodes(cg3, name = "A")
  expect_false(cg4@built)
  expect_equal(cg4@nodes$name, "B")
  expect_equal(nrow(cg4@edges), 0L)

  cg5 <- add_edges(cg2, A %-->% B, B %-->% C)
  cg6 <- remove_nodes(cg5)
  expect_equal(cg5, cg6) # no-op if no nodes given
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── inplace = FALSE ───────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("inplace = FALSE doesn't modify object for remove_nodes", {
  cg <- caugi(Z %-->% X %-->% Y, U %-->% X + Y)
  nodes_before <- cg@nodes
  edges_before <- cg@edges
  new_cg <- remove_nodes(cg, "U", inplace = FALSE)
  nodes_after <- cg@nodes
  edges_after <- cg@edges
  expect_equal(nodes_after, nodes_before)
  expect_equal(edges_after, edges_before)

  nodes_new_object <- new_cg@nodes
  edges_new_object <- new_cg@edges
  expect_equal(
    nodes_new_object,
    data.table::data.table(name = c("Z", "X", "Y"))
  )
  expect_equal(nrow(edges_new_object), 2L)
})

test_that("inplace = FALSE doesn't modify object for add_nodes", {
  cg <- caugi(Z %-->% X %-->% Y, U %-->% X + Y)
  nodes_before <- cg@nodes
  edges_before <- cg@edges
  new_cg <- add_nodes(cg, "W", inplace = FALSE)
  nodes_after <- cg@nodes
  edges_after <- cg@edges
  expect_equal(nodes_after, nodes_before)
  expect_equal(edges_after, edges_before)

  nodes_new_object <- new_cg@nodes
  edges_new_object <- new_cg@edges
  expect_equal(
    nodes_new_object,
    data.table::data.table(name = c("Z", "X", "U", "Y", "W"))
  )
  expect_equal(edges_new_object, edges_before)
})

test_that("inplace = FALSE doesn't modify object for remove_edges", {
  cg <- caugi(Z %-->% X %-->% Y, U %-->% X + Y)
  nodes_before <- cg@nodes
  edges_before <- cg@edges
  new_cg <- remove_edges(cg, from = "U", to = "X", inplace = FALSE)
  nodes_after <- cg@nodes
  edges_after <- cg@edges
  expect_equal(nodes_after, nodes_before)
  expect_equal(edges_after, edges_before)

  edges_new_object <- new_cg@edges
  expect_equal(nrow(edges_new_object), 3L)
})

test_that("inplace = FALSE doesn't modify object for add_edges", {
  cg <- caugi(Z %-->% X %-->% Y, U %-->% X + Y)
  nodes_before <- cg@nodes
  edges_before <- cg@edges
  new_cg <- add_edges(cg, Z %-->% U, inplace = FALSE)
  nodes_after <- cg@nodes
  edges_after <- cg@edges
  expect_equal(nodes_after, nodes_before)
  expect_equal(edges_after, edges_before)

  edges_new_object <- new_cg@edges
  expect_equal(nrow(edges_new_object), 5L)
})

test_that("inplace = FALSE doesn't modify object for set_edges", {
  cg <- caugi(Z %-->% X %-->% Y, U %-->% X + Y)
  nodes_before <- cg@nodes
  edges_before <- cg@edges
  new_cg <- set_edges(cg, U %---% X, inplace = FALSE)
  nodes_after <- cg@nodes
  edges_after <- cg@edges
  expect_equal(nodes_after, nodes_before)
  expect_equal(edges_after, edges_before)

  edges_new_object <- new_cg@edges
  expect_equal(edges_new_object$edge, c("-->", "-->", "-->", "---"))
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Hashmap updating ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("name_to_index_map updates when using verbs", {
  cg <- caugi()
  expect_equal(cg@name_index_map$size(), 0L)

  # adding nodes
  cg1 <- add_nodes(cg, name = c("A", "B"))
  expect_equal(cg1@name_index_map$size(), 2L)
  expect_identical(cg1@name_index_map$get("A"), 0L)
  expect_identical(cg1@name_index_map$get("B"), 1L)

  cg2 <- add_nodes(cg1, name = "C")
  expect_equal(cg2@name_index_map$size(), 3L)
  expect_equal(cg2@name_index_map$size(), 3L)
  expect_identical(cg2@name_index_map$get("C"), 2L)

  # removing nodes
  cg3 <- remove_nodes(cg2, name = "B")
  expect_equal(cg3@name_index_map$size(), 2L)
  expect_null(cg3@name_index_map$get("B"))

  # adding edges (should add nodes if missing)
  cg4 <- add_edges(cg3, from = "A", edge = "-->", to = "D")
  expect_equal(cg4@name_index_map$size(), 3L)
  expect_identical(cg4@name_index_map$get("D"), 2L)

  # remove several nodes
  cg5 <- remove_nodes(cg4, name = c("A", "C"))
  expect_equal(cg5@name_index_map$size(), 1L)
  expect_identical(cg5@name_index_map$get("D"), 0L)
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Internal getters ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".get_nodes branches", {
  expect_equal(
    caugi:::.get_nodes(NULL, list()),
    data.table::data.table(name = character())
  )
  expect_error(
    caugi:::.get_nodes(
      name = "A",
      calls = list(quote(A))
    ),
    "or `name`, not both"
  )
  res <- caugi:::.get_nodes(name = c("A", "A", "B"), calls = list())
  expect_setequal(res$name, c("A", "B"))
})

test_that(".get_edges vector path and error branches", {
  expect_error(caugi:::.get_edges(
    from = "A",
    edge = NULL,
    to = "B",
    calls = list()
  ))
  expect_error(caugi:::.get_edges(
    from = c("A", "B"),
    edge = c("-->"),
    to = c("B"),
    calls = list()
  ))

  res <- caugi:::.get_edges(
    from = c("A", "A"),
    edge = c("-->", "-->"),
    to = c("B", "B"),
    calls = list()
  )
  expect_equal(nrow(res), 2L)
})

test_that(".get_edges expression path branch", {
  res <- caugi:::.get_edges(
    from = NULL,
    edge = NULL,
    to = NULL,
    calls = list(
      quote(A %-->% B),
      quote(B %---% C)
    )
  )
  expect_equal(nrow(res), 2L)
  expect_equal(res$from, c("A", "B"))
  expect_equal(res$edge, c("-->", "---"))
  expect_equal(res$to, c("B", "C"))
})

test_that(".get_edges works with empty input", {
  res <- caugi:::.get_edges(
    from = NULL,
    edge = NULL,
    to = NULL,
    calls = list()
  )
  expect_equal(nrow(res), 0L)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────── Internal build marker ─────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".mark_not_built flips flag", {
  cg <- caugi()
  cg <- add_nodes(cg, name = "A")
  cg <- build(cg)
  out <- caugi:::.mark_not_built(cg)
  expect_false(out@built)
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Internal updater ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".update_caugi add/remove paths and validations", {
  cg <- caugi()
  cg1 <- caugi:::.update_caugi(
    cg,
    nodes = data.table::data.table(
      name = c("A", "B", "B")
    ),
    action = "add"
  )
  expect_false(cg1@built)
  expect_setequal(cg1@nodes$name, c("A", "B"))

  cg2 <- caugi:::.update_caugi(
    cg1,
    edges = data.table::data.table(
      from = c("A", "A"),
      edge = c("-->", "-->"),
      to = c("B", "B")
    ),
    action = "add",
    inplace = FALSE
  )
  expect_equal(nrow(cg2@edges), 1L)
  expect_setequal(cg2@nodes$name, c("A", "B"))

  cg3 <- caugi()
  cg3 <- add_nodes(cg3, name = c("A", "B", "C"))
  cg3 <- add_edges(
    cg3,
    from = c("A", "B", "A"),
    edge = c("-->", "<->", "o->"),
    to = c("B", "C", "C")
  )
  cg4 <- caugi:::.update_caugi(
    cg3,
    edges = data.table::data.table(
      from = "A",
      to = "B"
    ),
    action = "remove"
  )
  expect_false(any(cg4@edges$from == "A" & cg4@edges$to == "B"))

  expect_error(
    caugi:::.update_caugi(
      cg4,
      edges = data.table::data.table(from = "B"),
      action = "remove"
    ),
    "include at least `from` and `to`."
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Additional Coverage ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("build() rejects extra arguments", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    build(cg, extra_arg = TRUE),
    "does not take any arguments other than"
  )
})

test_that("remove_edges errors when cg is not simple and edge is NULL", {
  cg <- caugi(
    A %-->% B,
    A %<->% B,
    class = "ADMG",
    simple = FALSE
  )
  expect_error(
    remove_edges(cg, from = "A", to = "B"),
    "When removing edges without specifying `edge`, `cg` must be simple"
  )
})

test_that("remove_edges errors when from/to missing with NULL edge", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    remove_edges(cg, from = "A"),
    "`from` and `to` must be supplied when `edge` is omitted"
  )
  expect_error(
    remove_edges(cg, to = "B"),
    "`from` and `to` must be supplied when `edge` is omitted"
  )
})

test_that("remove_edges errors when from/to have different lengths", {
  cg <- caugi(A %-->% B + C, class = "DAG")
  expect_error(
    remove_edges(cg, from = c("A", "A"), to = "B"),
    "`from` and `to` must be equal length"
  )
})
