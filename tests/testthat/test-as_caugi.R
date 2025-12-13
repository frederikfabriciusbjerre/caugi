# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Matrix conversion ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("integer adjacency → DAG works and preserves names", {
  m <- matrix(0L, 3, 3, dimnames = list(LETTERS[1:3], LETTERS[1:3]))
  m["A", "B"] <- 1L
  m["B", "C"] <- 1L

  cg <- as_caugi(m, class = "DAG")

  expect_true(S7::S7_inherits(cg, class = caugi))
  # nodes() should expose vertex names
  expect_setequal(nodes(cg)[["name"]], c("A", "B", "C"))

  e <- as.data.frame(edges(cg))
  expect_setequal(names(e), c("from", "edge", "to"))
  exp <- data.frame(
    from = c("A", "B"),
    edge = c("-->", "-->"),
    to = c("B", "C"),
    stringsAsFactors = FALSE
  )
  expect_equal(e[order(e$from, e$to), ], exp[order(exp$from, exp$to), ])
})

test_that("collapse merges mutual directed edges to undirected", {
  m <- matrix(0L, 2, 2, dimnames = list(c("A", "B"), c("A", "B")))
  m["A", "B"] <- 1L
  m["B", "A"] <- 1L

  cg_no <- as_caugi(m, class = "UNKNOWN", collapse = FALSE, simple = FALSE)
  cg_yes <- as_caugi(m, class = "PDAG", collapse = TRUE)

  e_no <- as.data.frame(edges(cg_no))
  e_yes <- as.data.frame(edges(cg_yes))

  expect_equal(nrow(e_no), 2L)
  expect_true(all(e_no$edge == "-->"))

  expect_equal(nrow(e_yes), 1L)
  expect_equal(e_yes$from, "A")
  expect_equal(e_yes$to, "B")
  expect_equal(e_yes$edge, "---")
})

test_that("matrix validation errors", {
  # non-square
  m_bad <- matrix(0L, 2, 3)
  expect_error(as_caugi(m_bad), "square adjacency matrix", fixed = TRUE)

  # non-integer numeric entries
  x <- matrix(0, 2, 2)
  x[1, 2] <- 0.5
  expect_error(as_caugi(x), "logical or a non-negative integer", fixed = TRUE)

  # invalid codes for non-PAG
  y <- matrix(0L, 2, 2)
  y[1, 2] <- 1L # circle endpoints
  y[2, 1] <- 2L # arrow endpoint
  expect_error(
    as_caugi(y, class = "DAG"),
    "Only either 0:1 are allowed or 0,2,3"
  )

  # invalid codes for PAG
  z <- matrix(0L, 2, 2)
  z[1, 2] <- 4L
  expect_error(as_caugi(z, class = "PAG"), "integer codes 0-3", fixed = TRUE)
})

test_that("logical matrices are accepted for non-PAG and rejected for PAG", {
  m <- matrix(FALSE, 2, 2)
  m[1, 2] <- TRUE

  expect_silent(as_caugi(m, class = "DAG"))

  expect_error(
    as_caugi(m, class = "PAG"),
    "PAG class is not supported for logical matrices",
    fixed = TRUE
  )
})

test_that("default names V1..Vn when dimnames are missing", {
  m <- matrix(0L, 2, 2)
  m[1, 2] <- 1L
  cg <- as_caugi(m, class = "DAG")
  expect_setequal(nodes(cg)[["name"]], c("V1", "V2"))
})

test_that("PAG code pairs map to expected glyphs", {
  nm <- c("A", "B", "C", "D")
  M <- matrix(0L, 4, 4, dimnames = list(nm, nm))

  # A-B: tail-arrow => A --> B
  M["A", "B"] <- 2L # mark at B end
  M["B", "A"] <- 3L # mark at A end

  # A-C: tail-tail => A --- C
  M["A", "C"] <- 3L
  M["C", "A"] <- 3L

  # B-C: circle-arrow => B o-> C
  M["B", "C"] <- 2L
  M["C", "B"] <- 1L

  # C-D: arrow-arrow => C <-> D
  M["C", "D"] <- 2L
  M["D", "C"] <- 2L

  cg <- as_caugi(M, class = "PAG")
  e <- as.data.frame(edges(cg))[c("from", "edge", "to")]

  exp <- rbind(
    data.frame(from = "A", edge = "-->", to = "B"),
    data.frame(from = "A", edge = "---", to = "C"),
    data.frame(from = "B", edge = "o->", to = "C"),
    data.frame(from = "C", edge = "<->", to = "D")
  )
  ord <- function(df) df[order(df$from, df$edge, df$to), , drop = FALSE]
  expect_equal(ord(e), ord(exp))
})

test_that("double and logical matrices dispatch via integer method", {
  m_d <- matrix(0, 2, 2)
  m_d[1, 2] <- 1
  m_l <- matrix(FALSE, 2, 2)
  m_l[1, 2] <- TRUE

  cg_d <- as_caugi(m_d, class = "DAG")
  cg_l <- as_caugi(m_l, class = "DAG")

  e_d <- as.data.frame(edges(cg_d))
  e_l <- as.data.frame(edges(cg_l))

  expect_equal(e_d$edge, "-->")
  expect_equal(e_l$edge, "-->")
  expect_equal(e_d$from, "V1")
  expect_equal(e_d$to, "V2")
  expect_equal(e_l$from, "V1")
  expect_equal(e_l$to, "V2")
})

test_that("Matrix::Matrix dispatch works", {
  skip_if_not_installed("Matrix")
  m <- Matrix::Matrix(0L, 3, 3, sparse = FALSE)
  dimnames(m) <- list(LETTERS[1:3], LETTERS[1:3])
  m["A", "B"] <- 1L
  m["B", "C"] <- 1L

  cg <- as_caugi(m, class = "DAG")
  e <- as.data.frame(edges(cg))
  expect_setequal(e$edge, c("-->", "-->"))
  expect_setequal(e$from, c("A", "B"))
  expect_setequal(e$to, c("B", "C"))
})

test_that("Empty matrix yields empty caugi graph", {
  m0 <- matrix(integer(0), 0, 0)
  cg0 <- as_caugi(m0, class = "DAG")
  expect_equal(nrow(as.data.frame(edges(cg0))), 0L)
  expect_equal(nrow(nodes(cg0)), 0L)
})

test_that("Matrix with no edges works", {
  m0 <- matrix(0L, 3, 3)
  dimnames(m0) <- list(c("A", "B", "C"), c("A", "B", "C"))
  cg0 <- as_caugi(m0, class = "DAG")
  expect_equal(nrow(as.data.frame(edges(cg0))), 0L)
  expect_setequal(nodes(cg0)[["name"]], c("A", "B", "C"))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── igraph conversion ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("igraph dispatch works and respects directedness + collapse", {
  skip_if_not_installed("igraph")

  ed <- matrix(c("A", "B", "B", "C"), ncol = 2, byrow = TRUE)

  g_dir <- igraph::graph_from_edgelist(ed, directed = TRUE)
  cg_dir <- as_caugi(g_dir, class = "DAG")
  e_dir <- as.data.frame(edges(cg_dir))
  expect_true(all(e_dir$edge == "-->"))
  expect_setequal(e_dir$from, c("A", "B"))
  expect_setequal(e_dir$to, c("B", "C"))

  g_undir <- igraph::graph_from_edgelist(ed, directed = FALSE)
  cg_undir <- as_caugi(g_undir, class = "UNKNOWN")
  e_un <- as.data.frame(edges(cg_undir))
  expect_true(all(e_un$edge == "---"))

  g_mut <- igraph::graph_from_edgelist(
    matrix(c("A", "B", "B", "A"), 2, 2, byrow = TRUE),
    directed = TRUE
  )
  cg_col <- as_caugi(g_mut, class = "PDAG", collapse = TRUE)
  e_col <- as.data.frame(edges(cg_col))
  expect_equal(nrow(e_col), 1L)
  expect_equal(e_col$from, "A")
  expect_equal(e_col$to, "B")
  expect_equal(e_col$edge, "---")
})

test_that("empty igraph yield empty caugi graphs", {
  skip_if_not_installed("igraph")
  g0 <- igraph::make_empty_graph(n = 0, directed = TRUE)
  cg0 <- as_caugi(g0, class = "DAG")
  expect_equal(nrow(as.data.frame(edges(cg0))), 0L)
})

test_that("igraph with no edges, but with nodes, works", {
  skip_if_not_installed("igraph")
  g0 <- igraph::make_empty_graph(n = 3, directed = TRUE)
  igraph::V(g0)$name <- c("A", "B", "C")
  cg0 <- as_caugi(g0, class = "DAG")
  expect_equal(nrow(as.data.frame(edges(cg0))), 0L)
  expect_setequal(nodes(cg0)[["name"]], c("A", "B", "C"))
})

test_that("igraph with no edges and no names preserves order", {
  skip_if_not_installed("igraph")
  g0 <- igraph::make_empty_graph(n = 5, directed = TRUE)
  # Verify no names
  expect_null(igraph::V(g0)$name)

  cg0 <- as_caugi(g0, class = "DAG")
  expect_equal(nrow(as.data.frame(edges(cg0))), 0L)
  # Should generate V1, V2, V3, V4, V5 in order
  expect_equal(cg0@nodes$name, paste0("V", 1:5))
})

test_that("igraph vertex order is preserved when converting to caugi", {
  skip_if_not_installed("igraph")
  set.seed(1022)
  g <- igraph::sample_gnm(10, 5) |> igraph::as_directed(mode = "acyclic")
  igraph::V(g)$name <- paste0("V", 1:length(igraph::V(g)))

  # Convert to caugi
  cg <- as_caugi(g, class = "DAG")

  # Vertex order should be preserved
  expect_equal(V(cg)$name, igraph::V(g)$name)
  expect_equal(V(cg)$name, paste0("V", 1:10))
})

test_that("igraph without names: vertex order is preserved (issue #XX)", {
  skip_if_not_installed("igraph")

  # Create igraph WITHOUT names - this is the exact issue scenario
  # When no name is given to igraph, the order should not be scrambled
  set.seed(1023)
  ig <- igraph::sample_gnm(100, 500) |> igraph::as_directed(mode = "acyclic")
  # Verify the graph has no names
  expect_null(igraph::V(ig)$name)

  # Convert to caugi - names should be generated in order V1, V2, ..., V100
  cg <- as_caugi(ig, class = "DAG")

  # The nodes should be in sequential order V1, V2, ..., V100
  expected_names <- paste0("V", 1:100)
  expect_equal(cg@nodes$name, expected_names)

  # Also verify edges use the correct node names
  edges_df <- as.data.frame(edges(cg))
  # All from/to values should be valid names from expected_names
  expect_true(all(edges_df$from %in% expected_names))
  expect_true(all(edges_df$to %in% expected_names))
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── graphNEL conversion ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("graphNEL dispatch works (directed and undirected)", {
  skip_if_not_installed("graph")

  g <- graph::graphNEL(nodes = c("A", "B", "C"), edgemode = "directed")
  g <- graph::addEdge("A", "B", g)
  g <- graph::addEdge("B", "C", g)
  cg <- as_caugi(g, class = "DAG")
  e <- as.data.frame(edges(cg))
  expect_true(all(e$edge == "-->"))
  expect_setequal(e$from, c("A", "B"))
  expect_setequal(e$to, c("B", "C"))

  h <- graph::graphNEL(nodes = c("A", "B"), edgemode = "undirected")
  h <- graph::addEdge("A", "B", h)
  cg_u <- as_caugi(h, class = "UNKNOWN", simple = FALSE)
  eu <- as.data.frame(edges(cg_u))
  expect_equal(nrow(eu), 1L)
  expect_equal(eu$edge, "---")
})


test_that("graphNEL with no edges, but with nodes, works", {
  skip_if_not_installed("graph")
  h0 <- graph::graphNEL(nodes = c("A", "B", "C"), edgemode = "directed")
  cg0 <- as_caugi(h0, class = "DAG")
  expect_equal(nrow(as.data.frame(edges(cg0))), 0L)
  expect_setequal(nodes(cg0)[["name"]], c("A", "B", "C"))
})

test_that("collapse && directed for graphNEL conversion to caugi", {
  skip_if_not_installed("graph")

  g_mut <- graph::graphNEL(nodes = c("A", "B"), edgemode = "directed")
  g_mut <- graph::addEdge("A", "B", g_mut)
  g_mut <- graph::addEdge("B", "A", g_mut)

  cg_col <- as_caugi(g_mut, class = "PDAG", collapse = TRUE)
  e_col <- as.data.frame(edges(cg_col))
  expect_equal(nrow(e_col), 1L)
  expect_equal(e_col$from, "A")
  expect_equal(e_col$to, "B")
  expect_equal(e_col$edge, "---")
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── dagitty conversion ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("dagitty -> caugi: empty graph with isolates builds node set only", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("dag { A; B; C }")
  cg <- as_caugi(g, class = "DAG", build = TRUE)

  expect_s3_class(cg, "S7_object")
  expect_identical(sort(cg@nodes$name), c("A", "B", "C"))
  expect_equal(nrow(cg@edges), 0L)
})

test_that("dagitty -> caugi: directed edges map to '-->' with forward and reverse notations", {
  skip_if_not_installed("dagitty")
  g1 <- dagitty::dagitty("dag { A -> B }")
  cg1 <- as_caugi(g1, class = "DAG")

  expect_equal(cg1@edges$from, "A")
  expect_equal(cg1@edges$to, "B")
  expect_equal(cg1@edges$edge, "-->")

  # reverse arrow notation in dagitty input
  g2 <- dagitty::dagitty("dag { B <- A }")
  cg2 <- as_caugi(g2, class = "DAG")

  expect_equal(cg2@edges$from, "A")
  expect_equal(cg2@edges$to, "B")
  expect_equal(cg2@edges$edge, "-->")
})

test_that("dagitty -> caugi: undirected '--' maps to '---' and canonicalizes order", {
  skip_if_not_installed("dagitty")
  # only specified as B -- A; output should be A --- B
  g <- dagitty::dagitty("pdag { B -- A }")
  cg <- as_caugi(g, class = "PDAG")

  expect_equal(cg@edges$from, "A")
  expect_equal(cg@edges$to, "B")
  expect_equal(cg@edges$edge, "---")
})

test_that("dagitty -> caugi: bidirected '<->' is preserved", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("pdag { A <-> B }")
  cg <- as_caugi(g, class = "UNKNOWN")

  expect_equal(sort(c(cg@edges$from, cg@edges$to)), c("A", "B"))
  expect_equal(cg@edges$edge, "<->")
})

test_that("dagitty -> caugi: partial edges 'o->' and 'o-o' map correctly", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("pag { A @-> B; C @-@ D }")
  cg <- as_caugi(g, class = "PAG")

  expect_true(any(
    cg@edges$from == "A" & cg@edges$to == "B" & cg@edges$edge == "o->"
  ))
  expect_true(any(
    cg@edges$from == "C" & cg@edges$to == "D" & cg@edges$edge == "o-o"
  ))
})

test_that("dagitty -> caugi: collapse mutual directed pairs to symmetric glyph", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("dag { A -> B; B -> A }")
  cg_noc <- as_caugi(g, class = "UNKNOWN", collapse = FALSE, simple = FALSE)
  expect_equal(nrow(cg_noc@edges), 2L)
  expect_setequal(cg_noc@edges$edge, c("-->"))

  cg_col <- as_caugi(g, class = "PDAG", collapse = TRUE, collapse_to = "---")
  expect_equal(nrow(cg_col@edges), 1L)
  expect_equal(cg_col@edges$from, "A")
  expect_equal(cg_col@edges$to, "B")
  expect_equal(cg_col@edges$edge, "---")
})

test_that("dagitty -> caugi: isolates are retained alongside edges", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("dag { A -> B; C }")
  cg <- as_caugi(g, class = "DAG")

  expect_setequal(cg@nodes$name, c("A", "B", "C"))
  expect_equal(nrow(cg@edges), 1L)
})

test_that("dagitty -> caugi: PAG class is routed to UNKNOWN until supported", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("pag { A @-> B }")
  cg <- as_caugi(g, class = "PAG", build = TRUE)

  # graph_class getter returns uppercase from Rust; compare in upper
  expect_identical(toupper(cg@graph_class), "UNKNOWN")
  expect_true(any(cg@edges$edge == "o->"))
})

test_that("dagitty -> caugi: respects `simple` flag and builds pointer when requested", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("dag { A -> B }")
  cg <- as_caugi(g, class = "DAG", simple = TRUE, build = TRUE)

  expect_true(isTRUE(cg@built))
  expect_true(isTRUE(cg@simple))
  expect_false(is.null(cg@ptr))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── bnlearn conversion ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("bnlearn bn: isolates only", {
  skip_if_not_installed("bnlearn")
  g <- bnlearn::empty.graph(nodes = c("A", "B", "C"))
  cg <- as_caugi(g, class = "DAG", build = TRUE)
  expect_s3_class(cg, "S7_object")
  expect_setequal(cg@nodes$name, c("A", "B", "C"))
  expect_equal(nrow(cg@edges), 0L)
})

test_that("bnlearn bn: arcs map to '-->'", {
  skip_if_not_installed("bnlearn")
  g <- bnlearn::empty.graph(nodes = c("A", "B"))
  g <- bnlearn::set.arc(g, "A", "B")
  cg <- as_caugi(g, class = "DAG")
  expect_equal(nrow(cg@edges), 1L)
  expect_equal(cg@edges$from, "A")
  expect_equal(cg@edges$to, "B")
  expect_equal(cg@edges$edge, "-->")
})

test_that("as_caugi with bnlearn and collapse = TRUE", {
  skip_if_not_installed("igraph")
  skip_if_not_installed("bnlearn")
  # don't know how to do it any other way
  g <- igraph::graph_from_edgelist(
    matrix(c("A", "B", "B", "A"), ncol = 2, byrow = TRUE),
    directed = TRUE
  )
  g <- bnlearn::as.bn(g)
  cg <- as_caugi(g, class = "PDAG", collapse = TRUE)
  expect_equal(nrow(cg@edges), 1L)
  expect_equal(unique(cg@edges$edge), "---")
})
