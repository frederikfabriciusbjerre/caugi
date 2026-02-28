# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Queries tests ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── caugi type check ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("is_caugi works", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_true(is_caugi(cg))

  not_cg <- list(a = 1, b = 2)
  expect_false(is_caugi(not_cg))

  expect_error(is_caugi(not_cg, throw_error = TRUE))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Acyclicity ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────
test_that("acyclicity check works", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% A)

  expect_false(is_acyclic(cg))

  cg <- cg |> set_edges(C %---% A)
  expect_true(is_acyclic(cg))
})

test_that("is_acyclic forces check when requested", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")

  expect_true(is_acyclic(cg))
  expect_true(is_acyclic(cg, force_check = TRUE))
})

test_that("is_simple reflects declared state and force_check path", {
  cg_simple <- caugi(A %-->% B, class = "DAG")
  expect_true(is_simple(cg_simple))
  expect_true(is_simple(cg_simple, force_check = TRUE))

  cg_nonsimple <- caugi(
    A %-->% B,
    A %<->% B,
    class = "UNKNOWN",
    simple = FALSE
  )
  expect_false(is_simple(cg_nonsimple))
  expect_false(is_simple(cg_nonsimple, force_check = TRUE))
})

test_that("query builds", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_true(!is.null(cg@session))

  cg <- cg |> add_edges(D %-->% E)
  expect_true(!is.null(cg@session))

  expect_true(is_acyclic(cg))

  # now it should be build
  expect_true(!is.null(cg@session))
})

test_that("build initializes session without querying", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  state_before <- rs_is_valid(cg@session)
  expect_true(state_before$core_valid)
  expect_false(state_before$view_valid)

  expect_invisible(build(cg))

  state_after <- rs_is_valid(cg@session)
  expect_true(state_after$core_valid)
  expect_true(state_after$view_valid)

  # Build should not change graph content
  expect_setequal(nodes(cg)$name, c("A", "B", "C"))
  expect_equal(nrow(edges(cg)), 2L)
})

test_that("build is idempotent and survives updates", {
  cg <- caugi(A %-->% B, class = "DAG")
  build(cg)
  state_built <- rs_is_valid(cg@session)
  expect_true(state_built$core_valid)
  expect_true(state_built$view_valid)

  # idempotent
  build(cg)
  state_built2 <- rs_is_valid(cg@session)
  expect_true(state_built2$core_valid)
  expect_true(state_built2$view_valid)

  # updating invalidates session; build again should restore
  cg <- add_edges(cg, B %-->% C)
  state_after_update <- rs_is_valid(cg@session)
  expect_true(state_after_update$core_valid)
  expect_false(state_after_update$view_valid)

  build(cg)
  state_rebuilt <- rs_is_valid(cg@session)
  expect_true(state_rebuilt$core_valid)
  expect_true(state_rebuilt$view_valid)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Is it <type>? ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("is_dag works", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")
  expect_true(is_dag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_false(is_dag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "PDAG")
  expect_true(is_dag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "Unknown")
  expect_false(is_dag(cg))

  cg <- cg |> set_edges(C %-->% D)
  expect_true(is_dag(cg))
})

test_that("is_pdag works", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_true(is_pdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")
  expect_true(is_pdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "Unknown")
  expect_true(is_pdag(cg))

  cg <- cg |> set_edges(C %o->% D)
  expect_false(is_pdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %o->% D, class = "Unknown")

  expect_false(is_pdag(cg))
})

test_that("is_cpdag works", {
  # Triangle with A--B undirected and A->C, B->C directed.
  # Since A and B are adjacent, there's NO v-structure at C.
  # Directed edges are not protected, so NOT a valid CPDAG.
  cg <- caugi(A %-->% C, B %-->% C, A %---% B, class = "PDAG")
  expect_false(is_cpdag(cg))

  # Regression test: A->B, C->B with A--C undirected (triangle).
  # Same reasoning: A and C are adjacent, so no v-structure at B.
  # The directed edges A->B and C->B are not protected.
  cg <- caugi(A %-->% B, C %-->% B, C %---% A, class = "PDAG")
  expect_false(is_cpdag(cg))

  # A pure directed chain is NOT a valid CPDAG (edges not protected)
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")
  expect_false(is_cpdag(cg))

  # V-structure 0 -> 2 <- 1 IS a valid CPDAG
  cg <- caugi(A %-->% C, B %-->% C, class = "PDAG")
  expect_true(is_cpdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %o->% D, class = "Unknown")
  expect_false(is_cpdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D + E %o->% F, class = "Unknown")
  expect_false(is_cpdag(cg))

  cg <- caugi(A %-->% B, class = "PDAG")
  expect_false(is_cpdag(cg))

  cg <- caugi(A, B, class = "PDAG")
  expect_true(is_cpdag(cg))

  cg <- caugi(A %-->% B, A %---% C, class = "PDAG")
  expect_false(is_cpdag(cg))

  cg <- caugi(
    B %---% A,
    B %---% D,
    C %-->% E,
    B %-->% E,
    D %-->% F,
    E %-->% F,
    class = "PDAG"
  )
  expect_true(is_cpdag(cg))
})

test_that("same_nodes works", {
  cg1 <- caugi(A %-->% B, B %-->% C, class = "DAG")
  cg2 <- caugi(B %-->% C, A %-->% B, class = "DAG")
  cg3 <- caugi(A %-->% B, C %-->% D, class = "DAG")

  expect_true(same_nodes(cg1, cg2))
  expect_false(same_nodes(cg1, cg3))
  expect_error(same_nodes(cg1, cg3, throw_error = TRUE))
})

test_that("is_ug works", {
  cg <- caugi(A %---% B, B %---% C, C %---% D, class = "UG")
  expect_true(is_ug(cg))
  expect_true(is_ug(cg, force_check = TRUE))

  cg <- caugi(A %-->% B, B %---% C, C %---% D, class = "PDAG")
  expect_false(is_ug(cg))

  cg <- caugi(A %---% B, B %---% C, C %o->% D, class = "Unknown")
  expect_false(is_ug(cg))
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Getter queries ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("parents returns expected nodes for names, indices, and expr", {
  cg <- caugi(A %-->% B, B %-->% C, A %---% D, D %-->% B, class = "PDAG")
  expect_identical(parents(cg, "B"), c("A", "D"))
  expect_identical(parents(cg, "B"), c("A", "D"))
  pa_AB <- parents(cg, c("A", "B"))
  expect_null(pa_AB[["A"]])
  expect_setequal(pa_AB[["B"]], c("A", "D"))
  expect_identical(parents(cg, index = 2), c("A", "D"))
  pa_BC <- parents(cg, c("B", "C"))
  expect_setequal(pa_BC[["B"]], c("A", "D"))
  expect_setequal(pa_BC[["C"]], "B")
})

test_that("children returns expected nodes", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, D %-->% E, class = "PDAG")
  expect_identical(children(cg, "A")[[1]], "B")
  expect_identical(children(cg, c("B", "D"))[[1]], "C")
  expect_identical(children(cg, c("C", "D"))[[2]], "E")
  # indices
  expect_identical(children(cg, index = 1)[[1]], "B")
})

test_that("neighbors returns undirected and directed adjacency", {
  cg <- caugi(A %-->% B, B %-->% C, B %---% D, C %---% E, class = "PDAG")
  # B has neighbors A (incoming), C (outgoing), D (undirected)
  expect_setequal(neighbors(cg, "B"), c("A", "C", "D"))
  # C has neighbors B and E
  expect_setequal(neighbors(cg, "C"), c("B", "E"))
})

test_that("queries match with nodes and indexes", {
  cg <- caugi(A %-->% B, B %-->% C, B %---% D, C %---% E, class = "PDAG")
  expect_identical(children(cg, "A"), children(cg, index = 1))
  expect_identical(parents(cg, "B"), parents(cg, index = 2))
  expect_identical(neighbors(cg, "C"), neighbors(cg, index = 3))
})

test_that("queries fail with bad input", {
  cg <- caugi(A %-->% B, B %-->% C, B %---% D, C %---% E, class = "PDAG")
  expect_error(children(cg, "A", index = 1), "Supply either `nodes` or `index`")
  expect_error(children(cg), "Must supply either `nodes` or `index`.")
  expect_error(parents(cg, "A", index = 1), "Supply either `nodes` or `index`")
  expect_error(parents(cg), "Must supply either `nodes` or `index`.")
  expect_error(
    neighbors(cg, "A", index = 1),
    "Supply either `nodes` or `index`"
  )
  expect_error(neighbors(cg), "Must supply either `nodes` or `index`.")
  expect_error(ancestors(cg, "Z"), "Non-existent node name: Z")
  expect_error(
    ancestors(cg, "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
  expect_error(
    ancestors(cg),
    "Must supply either `nodes` or `index`."
  )
  expect_error(descendants(cg, index = 0), "must be >= 0")
  expect_error(
    descendants(cg, "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
  expect_error(
    descendants(cg),
    "Must supply either `nodes` or `index`."
  )
})

test_that("getter queries handle missing relations and duplicates", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  # node with no parents
  expect_identical(length(parents(cg, "A")[[1]]), 0L)
  # node with no children
  expect_identical(length(children(cg, "C")[[1]]), 0L)
  # duplicate targets collapse to the same combined set
  res <- parents(cg, c("B", "B"))
  expect_identical(sort(res[[1]]), sort(parents(cg, "B")[[1]]))
})

test_that("getter queries error on bad nodes or indices", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_error(parents(cg, "Z"), "Non-existent node name: Z")
  expect_error(children(cg, index = 0), "must be >= 0")
  expect_error(children(cg, index = 100), "out of bounds")
})

test_that("aliases route correctly", {
  cg <- caugi(A %-->% B, B %---% C, class = "PDAG")
  expect_identical(neighbours(cg, "B")[[1]], neighbors(cg, "B")[[1]])
})

test_that("public getters trigger lazy build", {
  cg <- caugi(A %-->% B, B %-->% C, class = "PDAG")
  cg <- cg |> add_edges(C %---% D)
  expect_true(!is.null(cg@session))
  parents(cg, "B")
  expect_true(!is.null(cg@session))
})

test_that("nodes and edges getters work", {
  cg <- caugi(A %-->% B, B %-->% C, class = "PDAG")
  nodes_out <- cg@nodes
  edges_out <- cg@edges

  expect_identical(nodes_out, nodes(cg))
  expect_identical(edges_out, edges(cg))

  expect_identical(nodes_out, vertices(cg))
  expect_identical(nodes_out, V(cg))

  expect_identical(edges_out, E(cg))

  expect_equal(nrow(nodes(cg)), 3L)
  expect_equal(nrow(edges(cg)), 2L)

  cg <- caugi()

  expect_equal(nrow(nodes(cg)), 0L)
  expect_equal(nrow(edges(cg)), 0L)
})

test_that("an and de works", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_identical(ancestors(cg, "C"), c("A", "B"))
  expect_identical(descendants(cg, "A"), c("B", "C"))
  expect_identical(sort(ancestors(cg, c("C", "D"))[[1]]), c("A", "B"))
  expect_identical(sort(descendants(cg, c("A", "D"))[[1]]), c("B", "C"))

  # test index
  expect_identical(ancestors(cg, index = 3), c("A", "B"))
  expect_identical(descendants(cg, index = 1), c("B", "C"))
  expect_identical(sort(ancestors(cg, index = c(3, 4))[[1]]), c("A", "B"))
  expect_identical(sort(descendants(cg, index = c(1, 4))[[1]]), c("B", "C"))

  cg <- caugi(A, B, class = "DAG")

  expect_equal(length(ancestors(cg, "A")), 0L)
  expect_equal(length(descendants(cg, "A")), 0L)
})

test_that("markov_blanket works on DAGs (parents, children, spouses)", {
  cg <- caugi(
    A %-->% B + C,
    D %-->% B,
    B %-->% E,
    F %-->% E,
    class = "DAG"
  )

  mb_A <- markov_blanket(cg, "A")
  expect_setequal(mb_A, c("B", "C", "D"))

  mb_B <- markov_blanket(cg, "B")
  expect_setequal(mb_B, c("A", "D", "E", "F"))

  # unquoted and vector inputs
  mb_AC <- markov_blanket(cg, c("A", "C"))
  expect_setequal(mb_AC[[1]], c("B", "C", "D"))
  expect_setequal(mb_AC[[2]], c("A"))

  # index input
  mb_idx <- markov_blanket(cg, index = 1)
  expect_setequal(mb_idx, c("B", "C", "D"))
})

test_that("markov_blanket includes undirected neighbors in PDAGs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    D %-->% B,
    class = "PDAG"
  )
  mb_B <- markov_blanket(cg, "B")
  expect_setequal(mb_B, c("A", "C", "D"))
})

test_that("markov_blanket matches a multi-parent fixture on DAGs", {
  cg <- caugi(
    W %-->% Y,
    X %-->% W,
    Z1 %-->% X + Z3,
    Z2 %-->% Y + Z3,
    Z3 %-->% X + Y,
    class = "DAG"
  )

  expect_setequal(markov_blanket(cg, "Z1"), c("X", "Z2", "Z3"))
  expect_setequal(markov_blanket(cg, "Y"), c("W", "Z2", "Z3"))
})

test_that("markov_blanket argument validation", {
  cg <- caugi(A %-->% B)
  expect_error(
    markov_blanket(cg),
    "Must supply either `nodes` or `index`."
  )
  expect_error(
    markov_blanket(cg, nodes = "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
})

test_that("exogenous works", {
  cg <- caugi(
    A %-->% B + C,
    D %-->% B,
    B %-->% E,
    F %-->% E,
    class = "DAG"
  )

  e <- exogenous(cg)
  expect_setequal(e, c("A", "D", "F"))

  cg <- caugi(A %---% B, C %-->% A, class = "PDAG")
  e <- exogenous(cg)
  expect_setequal(e, c("B", "C"))

  expect_error(exogenous("not a graph"), "Input must be a caugi")
})

test_that("exogenous works on PDAGs", {
  cg <- caugi(A %---% B, C %-->% D, class = "PDAG")
  e <- exogenous(cg)
  expect_setequal(e, c("A", "B", "C"))

  e <- exogenous(cg, undirected_as_parents = TRUE)
  expect_setequal(e, c("C"))
})

test_that("getter queries errors on non-character input", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_error(parents(cg, 1), "must be a character vector")
  expect_error(children(cg, 2), "must be a character vector")
  expect_error(neighbors(cg, 3), "must be a character vector")
  expect_error(ancestors(cg, 4), "must be a character vector")
  expect_error(descendants(cg, 5), "must be a character vector")
  expect_error(markov_blanket(cg, 6), "must be a character vector")
})

test_that("getter queries builds", {
  getter_queries <- c(
    parents,
    children,
    neighbors,
    ancestors,
    descendants,
    markov_blanket
  )
  for (getter in getter_queries) {
    cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
    getter(cg, "B")
    expect_true(!is.null(cg@session))
  }
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Getter helpers ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".getter_output returns data frame with name column", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  out <- caugi:::.getter_output(cg, c(0L, 2L), c("A", "C"))
  expect_identical(out[["A"]], "A")
  expect_identical(out[["C"]], "C")

  out_null <- caugi:::.getter_output(cg, 0L, NULL)
  expect_equal(out_null, "A")
})


# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Subgraph ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("subgraph selects nodes and errors with none", {
  cg <- caugi()
  cg <- add_nodes(cg, name = c("A", "B", "C"))
  cg <- add_edges(
    cg,
    from = c("A", "B"),
    edge = c("-->", "-->"),
    to = c("B", "C")
  )
  expect_error(subgraph(cg), "Must supply either `nodes` or `index`.")

  sg <- subgraph(cg, nodes = c("A", "B"))
  expect_setequal(sg@nodes$name, c("A", "B"))
  expect_equal(
    sg@edges,
    data.table::data.table(from = "A", edge = "-->", to = "B")
  )
})

test_that("subgraph errors on invalid arg combos", {
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B"),
    class = "UNKNOWN"
  )
  expect_error(subgraph(g), "Must supply either `nodes` or `index`.")
  expect_error(subgraph(g, nodes = "A", index = 1), "not both")
})

test_that("subgraph validates index", {
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B"),
    class = "UNKNOWN"
  )
  expect_error(subgraph(g, index = "a"), "`index` must be numeric")
  expect_error(
    subgraph(g, index = c(1, NA_integer_)),
    "`index` cannot contain NA values"
  )
  expect_error(subgraph(g, index = 0), "out of range")
  expect_error(subgraph(g, index = 3), "out of range")
})

test_that("subgraph validates nodes", {
  skip_if_not_installed("data.table")
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B"),
    class = "UNKNOWN"
  )
  expect_error(subgraph(g, nodes = 1), "character vector")
  expect_error(
    subgraph(g, nodes = c("A", NA_character_)),
    "`nodes` cannot contain NA values"
  )
  expect_error(subgraph(g, nodes = c("A", "Z")), "Unknown node\\(s\\): Z")
})

test_that("subgraph catches duplicates (nodes and index)", {
  g <- caugi(
    from = c("A", "B"),
    edge = c("-->", "-->"),
    to = c("C", "D"),
    nodes = c("A", "B", "C", "D"),
    class = "DAG"
  )
  expect_error(subgraph(g, nodes = c("A", "A")), "contains duplicates")
  expect_error(subgraph(g, index = c(1L, 1L)), "contains duplicates")
})

test_that("subgraph on graph without edges keeps nodes and empty edges", {
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B", "C"),
    class = "UNKNOWN"
  )
  s <- subgraph(g, nodes = c("C", "A"))
  expect_identical(s@nodes$name, c("C", "A"))
  expect_equal(nrow(s@edges), 0L)
  expect_true(!is.null(s@session))
  expect_identical(s@graph_class, g@graph_class)
  expect_identical(s@simple, g@simple)
})

test_that("subgraph filters edges to kept names and sorts", {
  g <- caugi(
    from = c("A", "B", "C", "A"),
    edge = c("-->", "-->", "---", "<->"),
    to = c("B", "C", "A", "C"),
    nodes = c("A", "B", "C", "D"),
    class = "UNKNOWN",
    simple = FALSE
  )
  # Keep C, A => should keep (A <-> C) and (C --- A), sorted by from,to,edge
  s <- subgraph(g, nodes = c("C", "A"))
  expect_identical(s@nodes$name, c("C", "A"))
  expect_equal(nrow(s@edges), 2L)
  expect_identical(s@edges$from, c("A", "C"))
  expect_identical(s@edges$to, c("C", "A"))
  expect_identical(s@edges$edge, c("<->", "---"))
})

test_that("subgraph with index matches nodes variant", {
  g <- caugi(
    from = c("A", "B", "C", "A"),
    edge = c("-->", "-->", "---", "-->"),
    to = c("D", "E", "G", "F"),
    nodes = c("A", "B", "C", "D", "E", "F", "G"),
    class = "PDAG"
  )
  s1 <- subgraph(g, nodes = c("B", "A", "C"))
  s2 <- subgraph(g, index = c(2L, 1L, 3L))
  expect_identical(s1@nodes$name, s2@nodes$name)
  expect_identical(s1@edges, s2@edges)
  expect_true(!is.null(s1@session) && !is.null(s2@session))
})

test_that("districts supports all, nodes, and index modes", {
  cg <- caugi(
    A %<->% B,
    B %<->% C,
    C %-->% D,
    class = "ADMG"
  )

  all_d <- districts(cg)
  expect_equal(length(all_d), 2L)
  expect_true(any(vapply(
    all_d,
    function(x) setequal(x, c("A", "B", "C")),
    logical(1)
  )))
  expect_true(any(vapply(all_d, function(x) identical(x, "D"), logical(1))))

  expect_setequal(districts(cg, nodes = "A"), c("A", "B", "C"))

  by_nodes <- districts(cg, nodes = c("A", "D"))
  expect_named(by_nodes, c("A", "D"))
  expect_setequal(by_nodes$A, c("A", "B", "C"))
  expect_identical(by_nodes$D, "D")

  by_index <- districts(cg, index = c(1L, 4L))
  expect_named(by_index, c("A", "D"))
  expect_setequal(by_index$A, c("A", "B", "C"))
  expect_identical(by_index$D, "D")
})

test_that("districts validates argument combinations", {
  cg <- caugi(A %<->% B, class = "ADMG")

  expect_error(
    districts(cg, nodes = "A", index = 1L),
    "either `nodes` or `index`"
  )
  expect_error(districts(cg, index = 0), "out of range")
  expect_error(districts(cg, nodes = c("A", NA_character_)), "without NA")
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────── UNKNOWN graph neighbor queries ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("neighbors mode 'all' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    class = "UNKNOWN"
  )

  # All neighbors
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))
  expect_setequal(neighbors(cg, "C", mode = "all"), c("B", "D"))
})

test_that("neighbors mode 'in' and 'out' work for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "UNKNOWN"
  )

  # In mode (parents)
  expect_null(neighbors(cg, "A", mode = "in"))
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_identical(neighbors(cg, "C", mode = "in"), "B")

  # Out mode (children)
  expect_identical(neighbors(cg, "A", mode = "out"), "B")
  expect_identical(neighbors(cg, "B", mode = "out"), "C")
  expect_null(neighbors(cg, "C", mode = "out"))
})

test_that("neighbors mode 'undirected' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %---% D,
    class = "UNKNOWN"
  )

  # Undirected mode (--- only, not <->)
  expect_null(neighbors(cg, "A", mode = "undirected"))
  expect_identical(neighbors(cg, "B", mode = "undirected"), "C")
  expect_setequal(neighbors(cg, "C", mode = "undirected"), c("B", "D"))
  expect_identical(neighbors(cg, "D", mode = "undirected"), "C")
})

test_that("neighbors mode 'bidirected' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    C %<->% D,
    class = "UNKNOWN"
  )

  # Bidirected mode (<-> only)
  expect_null(neighbors(cg, "A", mode = "bidirected"))
  expect_identical(neighbors(cg, "B", mode = "bidirected"), "C")
  expect_setequal(neighbors(cg, "C", mode = "bidirected"), c("B", "D"))
  expect_identical(neighbors(cg, "D", mode = "bidirected"), "C")
})

test_that("neighbors mode 'partial' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %o->% C,
    C %o-o% D,
    D %--o% E,
    class = "UNKNOWN"
  )

  # Partial mode returns neighbors where the CURRENT node has a Circle mark.
  # Edge marks:
  # A --> B: A has Tail, B has Arrow
  # B o-> C: B has Circle, C has Arrow
  # C o-o D: both have Circle
  # D --o E: D has Tail, E has Circle (head position has Circle)

  expect_null(neighbors(cg, "A", mode = "partial")) # A has Tail (no Circle)
  expect_identical(neighbors(cg, "B", mode = "partial"), "C") # B has Circle in B o-> C
  expect_identical(neighbors(cg, "C", mode = "partial"), "D") # C has Circle in C o-o D (but Arrow in B o-> C)
  expect_identical(neighbors(cg, "D", mode = "partial"), "C") # D has Circle in C o-o D (but Tail in D --o E)
  expect_identical(neighbors(cg, "E", mode = "partial"), "D") # E has Circle in D --o E
})

test_that("parents and children error for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    B %---% D,
    class = "UNKNOWN"
  )

  # parents, children, and spouses should error for UNKNOWN graphs
  # because only the structural neighbors() query should work
  expect_error(parents(cg, "B"), "not defined for UNKNOWN")
  expect_error(children(cg, "A"), "not defined for UNKNOWN")
  expect_error(spouses(cg, "A"), "not defined for UNKNOWN")

  # Use neighbors() with explicit mode instead
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_identical(neighbors(cg, "A", mode = "out"), "B")
})

test_that("neighbors mode with index works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "UNKNOWN"
  )

  # Using index parameter
  expect_identical(neighbors(cg, index = 2, mode = "in"), "A")
  expect_identical(neighbors(cg, index = 2, mode = "out"), "C")
})

test_that("neighbors mode works with multiple nodes for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    class = "UNKNOWN"
  )

  result <- neighbors(cg, c("B", "C"), mode = "in")
  expect_identical(names(result), c("B", "C"))
  expect_identical(result$B, "A")
  expect_identical(result$C, "B")
})

test_that("neighbors mode 'all' is default for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    class = "UNKNOWN"
  )

  # Default should be "all"
  expect_identical(
    neighbors(cg, "B"),
    neighbors(cg, "B", mode = "all")
  )
})

test_that("neighbors mode validation for DAG", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  # Valid modes for DAG: in, out, all
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_identical(neighbors(cg, "B", mode = "out"), "C")
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for DAG: undirected, bidirected, partial
  expect_error(neighbors(cg, "B", mode = "undirected"), "not valid for DAG")
  expect_error(neighbors(cg, "B", mode = "bidirected"), "not valid for DAG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for DAG")
})

test_that("neighbors mode validation for PDAG", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    class = "PDAG"
  )

  # Valid modes for PDAG: in, out, undirected, all
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_null(neighbors(cg, "B", mode = "out"))
  expect_identical(neighbors(cg, "B", mode = "undirected"), "C")
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for PDAG: bidirected, partial
  expect_error(neighbors(cg, "B", mode = "bidirected"), "not valid for PDAG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for PDAG")
})

test_that("neighbors mode validation for UG", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )

  # Valid modes for UG: undirected, all
  expect_setequal(neighbors(cg, "B", mode = "undirected"), c("A", "C"))
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for UG: in, out, bidirected, partial
  expect_error(neighbors(cg, "B", mode = "in"), "not defined for UG")
  expect_error(neighbors(cg, "B", mode = "out"), "not defined for UG")
  expect_error(neighbors(cg, "B", mode = "bidirected"), "not valid for UG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for UG")
})

test_that("neighbors mode validation for ADMG", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    class = "ADMG"
  )

  # Valid modes for ADMG: in, out, bidirected (spouses), all
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_null(neighbors(cg, "B", mode = "out"))
  expect_identical(neighbors(cg, "B", mode = "bidirected"), "C")
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for ADMG: undirected, partial
  expect_error(neighbors(cg, "B", mode = "undirected"), "not valid for ADMG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for ADMG")
})

test_that("spouses errors for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    C %---% D,
    class = "UNKNOWN"
  )

  # spouses should error for UNKNOWN graphs
  expect_error(spouses(cg, "B"), "not defined for UNKNOWN")

  # Use neighbors with mode = "bidirected" instead
  expect_identical(neighbors(cg, "B", mode = "bidirected"), "C")
  expect_identical(neighbors(cg, "C", mode = "bidirected"), "B")
  expect_null(neighbors(cg, "A", mode = "bidirected"))
  expect_null(neighbors(cg, "D", mode = "bidirected"))
})

test_that("spouses works for ADMG graphs", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    class = "ADMG"
  )

  # spouses returns bidirected neighbors (same as neighbors mode="bidirected")
  expect_null(spouses(cg, "A"))
  expect_identical(spouses(cg, "B"), "C")
  expect_identical(spouses(cg, "C"), "B")

  # spouses is equivalent to neighbors with mode = "bidirected"
  expect_identical(spouses(cg, "B"), neighbors(cg, "B", mode = "bidirected"))
})

test_that("spouses errors for graph types without bidirected edges", {
  cg_dag <- caugi(A %-->% B, class = "DAG")
  cg_pdag <- caugi(A %-->% B, B %---% C, class = "PDAG")
  cg_ug <- caugi(A %---% B, class = "UG")

  expect_error(spouses(cg_dag, "A"), "not valid for DAG")
  expect_error(spouses(cg_pdag, "A"), "not valid for PDAG")
  expect_error(spouses(cg_ug, "A"), "not valid for UG")
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Anteriors tests ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("anteriors works for DAG (equals ancestors)", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_null(anteriors(cg, "A"))
  expect_equal(anteriors(cg, "B"), "A")
  expect_equal(sort(anteriors(cg, "C")), c("A", "B"))
})

test_that("anteriors works for PDAG with mixed edges", {
  # PDAG: A -> B --- C, B -> D
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  # A has no anteriors
  expect_null(anteriors(cg, "A"))
  # B's anteriors: A (parent) and C (undirected)
  expect_equal(sort(anteriors(cg, "B")), c("A", "C"))
  # C's anteriors: B (undirected) -> A (parent of B)
  expect_equal(sort(anteriors(cg, "C")), c("A", "B"))
  # D's anteriors: B (parent) -> A (parent of B), C (undirected of B)
  expect_equal(sort(anteriors(cg, "D")), c("A", "B", "C"))
})

test_that("anteriors works for PDAG with undirected cycle", {
  # PDAG: A --- B --- C --- A (triangle)
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "PDAG"
  )
  # All nodes can reach all others via undirected edges
  expect_equal(sort(anteriors(cg, "A")), c("B", "C"))
  expect_equal(sort(anteriors(cg, "B")), c("A", "C"))
  expect_equal(sort(anteriors(cg, "C")), c("A", "B"))
})

test_that("anteriors not defined for UG", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )
  expect_error(anteriors(cg, "B"), "not defined for UG")
})

test_that("anteriors not defined for ADMG", {
  cg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )
  expect_error(anteriors(cg, "B"), "not defined for ADMG")
})

test_that("anteriors returns list for multiple nodes", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  result <- anteriors(cg, c("A", "D"))
  expect_type(result, "list")
  expect_named(result, c("A", "D"))
  expect_null(result$A)
  expect_equal(sort(result$D), c("A", "B", "C"))
})

# ────────────────────────────── Posteriors tests ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("posteriors works for DAG (equals descendants)", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_equal(sort(posteriors(cg, "A")), c("B", "C"))
  expect_equal(posteriors(cg, "B"), "C")
  expect_null(posteriors(cg, "C"))
})

test_that("posteriors works for PDAG with mixed edges", {
  # PDAG: A -> B --- C, B -> D
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  # A's posteriors: B (child) -> C (undirected of B), D (child of B)
  expect_equal(sort(posteriors(cg, "A")), c("B", "C", "D"))
  # B's posteriors: D (child) and C (undirected)
  expect_equal(sort(posteriors(cg, "B")), c("C", "D"))
  # C's posteriors: B (undirected) -> D (child of B)
  expect_equal(sort(posteriors(cg, "C")), c("B", "D"))
  # D has no posteriors
  expect_null(posteriors(cg, "D"))
})

test_that("posteriors works for PDAG with undirected cycle", {
  # PDAG: A --- B --- C --- A (triangle)
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "PDAG"
  )
  # All nodes can reach all others via undirected edges
  # For undirected-only graphs, posteriors == anteriors
  expect_equal(sort(posteriors(cg, "A")), c("B", "C"))
  expect_equal(sort(posteriors(cg, "B")), c("A", "C"))
  expect_equal(sort(posteriors(cg, "C")), c("A", "B"))
})

test_that("posteriors not defined for UG", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )
  expect_error(posteriors(cg, "B"), "not defined for UG")
})

test_that("posteriors not defined for ADMG", {
  cg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )
  expect_error(posteriors(cg, "B"), "not defined for ADMG")
})

test_that("posteriors returns list for multiple nodes", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  result <- posteriors(cg, c("A", "D"))
  expect_type(result, "list")
  expect_named(result, c("A", "D"))
  expect_equal(sort(result$A), c("B", "C", "D"))
  expect_null(result$D)
})

test_that("posteriors works with index parameter", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  # Index 1 is A (0-indexed becomes 1-indexed in R)
  expect_equal(sort(posteriors(cg, index = 1)), c("B", "C"))
  expect_equal(posteriors(cg, index = 2), "C")
})

test_that("posteriors excludes the node itself", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  res <- posteriors(cg, "A")
  expect_false("A" %in% res)
})

test_that("posteriors handles multi-step mixed reachability (PDAG)", {
  # A -> B --- C --- D -> E
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %---% D,
    D %-->% E,
    class = "PDAG"
  )

  # From A: B, C, D, E should all be reachable
  expect_equal(sort(posteriors(cg, "A")), c("B", "C", "D", "E"))
})

test_that("posteriors does not return duplicates in undirected cycles", {
  # A --- B --- C --- A
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "PDAG"
  )

  res <- posteriors(cg, "A")
  expect_equal(length(res), length(unique(res)))
})

test_that("posteriors handles branching mixed structure correctly", {
  #      B --- C
  #     /
  # A ->
  #     \
  #      D -> E
  cg <- caugi(
    A %-->% B,
    B %---% C,
    A %-->% D,
    D %-->% E,
    class = "PDAG"
  )

  expect_equal(sort(posteriors(cg, "A")), c("B", "C", "D", "E"))
})

test_that("posteriors works for multiple starting nodes (set semantics)", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    class = "DAG"
  )

  res <- posteriors(cg, c("A", "D"))

  expect_type(res, "list")
  expect_named(res, c("A", "D"))

  expect_equal(sort(res$A), c("B", "C"))
  expect_equal(res$D, "E")
})

test_that("posteriors returns empty (NULL) when no reachable nodes exist", {
  cg <- caugi(
    A %-->% B,
    class = "DAG"
  )

  expect_null(posteriors(cg, "B"))
})

test_that("posteriors respects disconnected components", {
  cg <- caugi(
    A %-->% B,
    C %-->% D,
    class = "DAG"
  )

  expect_equal(posteriors(cg, "A"), "B")
  expect_equal(posteriors(cg, "C")[posteriors(cg, "C") == "A"], character(0))
})

test_that("posteriors index parameter matches name-based query", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  nodes_vec <- nodes(cg)
  idx_A <- which(nodes_vec == "A")

  expect_equal(
    sort(posteriors(cg, index = idx_A)),
    sort(posteriors(cg, "A"))
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Closed graph definition tests ─────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("ancestors, anteriors, descendants, posteriors errors on not boolean open argument", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_error(
    ancestors(cg, "A", open = "hi"),
    "`open` must be a single TRUE or FALSE."
  )
  expect_error(
    anteriors(cg, "A", open = "hi"),
    "`open` must be a single TRUE or FALSE."
  )
  expect_error(
    descendants(cg, "A", open = "hi"),
    "`open` must be a single TRUE or FALSE."
  )
  expect_error(
    posteriors(cg, "A", open = c(TRUE, FALSE)),
    "`open` must be a single TRUE or FALSE."
  )
})

test_that("ancestors, anteriors, descendants, posteriors handles closed graph definition", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_equal(ancestors(cg, "A", open = FALSE), "A")
  expect_equal(ancestors(cg, "B", open = FALSE), c("B", "A"))

  expect_equal(anteriors(cg, "A", open = FALSE), "A")
  expect_equal(
    anteriors(cg, "C", open = FALSE),
    c("C", "A", "B")
  )

  expect_equal(
    descendants(cg, "A", open = FALSE),
    c("A", "B", "D")
  )
  expect_equal(descendants(cg, "B", open = FALSE), c("B", "D"))
  expect_equal(posteriors(cg, "A", open = FALSE), c("A", "B", "C", "D"))
  expect_equal(posteriors(cg, "B", open = FALSE), c("B", "C", "D"))
})

test_that("Setting use_open_graph_definition via caugi_options works", {
  caugi_options(use_open_graph_definition = FALSE)
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_equal(ancestors(cg, "A"), "A")
  expect_equal(ancestors(cg, "B"), c("B", "A"))

  expect_equal(anteriors(cg, "A"), "A")
  expect_equal(anteriors(cg, "C"), c("C", "A", "B"))

  expect_equal(descendants(cg, "A"), c("A", "B", "D"))
  expect_equal(descendants(cg, "B"), c("B", "D"))

  expect_equal(posteriors(cg, "A"), c("A", "B", "C", "D"))

  # Can still override with explicit argument
  expect_equal(ancestors(cg, "A", open = TRUE), NULL)
  expect_equal(anteriors(cg, "A", open = TRUE), NULL)
  expect_equal(descendants(cg, "A", open = TRUE), c("B", "D"))
  expect_equal(posteriors(cg, "A", open = TRUE), c("B", "C", "D"))

  # Reset to defaults
  caugi_options(caugi_default_options())
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────── open_graph_def fast-access env var ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("open_graph_def is TRUE by default", {
  expect_true(.caugi_env$open_graph_def)
})

test_that("open_graph_def syncs to FALSE when use_open_graph_definition is set FALSE", {
  on.exit(caugi_options(caugi_default_options()), add = TRUE)

  caugi_options(use_open_graph_definition = FALSE)
  expect_false(.caugi_env$open_graph_def)
})

test_that("open_graph_def syncs back to TRUE when use_open_graph_definition is set TRUE", {
  on.exit(caugi_options(caugi_default_options()), add = TRUE)

  caugi_options(use_open_graph_definition = FALSE)
  caugi_options(use_open_graph_definition = TRUE)
  expect_true(.caugi_env$open_graph_def)
})

test_that("open_graph_def is restored to TRUE by caugi_default_options()", {
  on.exit(caugi_options(caugi_default_options()), add = TRUE)

  caugi_options(use_open_graph_definition = FALSE)
  expect_false(.caugi_env$open_graph_def)

  caugi_options(caugi_default_options())
  expect_true(.caugi_env$open_graph_def)
})

test_that("open_graph_def is unaffected by unrelated option updates", {
  on.exit(caugi_options(caugi_default_options()), add = TRUE)

  caugi_options(plot = list(spacing = grid::unit(2, "lines")))
  expect_true(.caugi_env$open_graph_def)
})

test_that("missing(open) uses global option; explicit open overrides it", {
  on.exit(caugi_options(caugi_default_options()), add = TRUE)

  cg <- caugi(A %-->% B %-->% C, class = "DAG")

  # With default option (open = TRUE): node excluded
  expect_equal(ancestors(cg, "B"), "A")

  # Switch global option to closed; missing open now means closed
  caugi_options(use_open_graph_definition = FALSE)
  expect_equal(ancestors(cg, "B"), c("B", "A"))

  # Explicit open = TRUE overrides the closed global option
  expect_equal(ancestors(cg, "B", open = TRUE), "A")

  # Explicit open = FALSE overrides the open global option after reset
  caugi_options(use_open_graph_definition = TRUE)
  expect_equal(ancestors(cg, "B", open = FALSE), c("B", "A"))
})
