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

test_that("MPDAG class is accepted for matrix conversion", {
  m <- matrix(0L, 2, 2, dimnames = list(c("A", "B"), c("A", "B")))
  m["A", "B"] <- 1L

  cg <- as_caugi(m, class = "MPDAG")
  expect_identical(cg@graph_class, "MPDAG")
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
  ord <- function(df) df[order(df$from, df$edge, df$to), , drop = FALSE]
  decoded <- function(M) {
    cg <- as_caugi(M, class = "PAG")
    expect_identical(cg@graph_class, "PAG")
    as.data.frame(edges(cg))[c("from", "edge", "to")]
  }

  # Matrices carrying circle marks (code 1) can only be decoded via
  # `class = "PAG"`, and `class = "PAG"` now runs the complete PAG check, so
  # both fixtures below are graphs that really are PAGs (each is the PAG of a
  # MAG). A node carrying an undirected edge may not carry an arrowhead, so the
  # six code pairs are still split across two graphs.

  # arrow/tail, circle/arrow, arrow/arrow, circle/circle
  # PAG of a MAG on 5 nodes; the extra A <-> D edge is what makes the marks
  # invariant, it carries no code pair of its own.
  nm1 <- c("A", "C", "D", "B", "E")
  M1 <- matrix(0L, 5, 5, dimnames = list(nm1, nm1))
  M1["D", "B"] <- 2L # mark at B end   => D --> B   (arrow/tail)
  M1["B", "D"] <- 3L # mark at D end
  M1["C", "D"] <- 2L #                 => C o-> D  (circle/arrow)
  M1["D", "C"] <- 1L
  M1["A", "B"] <- 2L #                 => A <-> B  (arrow/arrow)
  M1["B", "A"] <- 2L
  M1["C", "E"] <- 1L #                 => C o-o E  (circle/circle)
  M1["E", "C"] <- 1L
  M1["A", "D"] <- 2L #                 => A <-> D
  M1["D", "A"] <- 2L

  expect_equal(
    ord(decoded(M1)),
    ord(rbind(
      data.frame(from = "A", edge = "<->", to = "B"),
      data.frame(from = "A", edge = "<->", to = "D"),
      data.frame(from = "C", edge = "o->", to = "D"),
      data.frame(from = "C", edge = "o-o", to = "E"),
      data.frame(from = "D", edge = "-->", to = "B")
    ))
  )

  # tail/tail and tail/circle
  # PAG of an undirected (selection-only) MAG on 5 nodes.
  nm2 <- c("A", "B", "C", "D", "E")
  M2 <- matrix(0L, 5, 5, dimnames = list(nm2, nm2))
  M2["A", "C"] <- 3L #                 => A --- C  (tail/tail)
  M2["C", "A"] <- 3L
  M2["A", "E"] <- 1L #                 => A --o E  (tail/circle)
  M2["E", "A"] <- 3L
  M2["A", "D"] <- 3L #                 => A --- D
  M2["D", "A"] <- 3L
  M2["B", "C"] <- 3L #                 => B --- C
  M2["C", "B"] <- 3L
  M2["B", "D"] <- 3L #                 => B --- D
  M2["D", "B"] <- 3L

  expect_equal(
    ord(decoded(M2)),
    ord(rbind(
      data.frame(from = "A", edge = "---", to = "C"),
      data.frame(from = "A", edge = "---", to = "D"),
      data.frame(from = "A", edge = "--o", to = "E"),
      data.frame(from = "B", edge = "---", to = "C"),
      data.frame(from = "B", edge = "---", to = "D")
    ))
  )
})

test_that("mark-coded matrices decode for non-PAG classes", {
  ord <- function(df) df[order(df$from, df$edge, df$to), , drop = FALSE]
  nm <- c("a", "b", "c", "d")

  # `amat.pag` coding of the MAG a --> b, b <-> c, b --> d, c --> d
  M <- matrix(
    c(0, 3, 0, 0, 2, 0, 2, 3, 0, 2, 0, 3, 0, 2, 2, 0),
    4,
    4,
    dimnames = list(nm, nm)
  )
  storage.mode(M) <- "integer"

  exp <- rbind(
    data.frame(from = "a", edge = "-->", to = "b"),
    data.frame(from = "b", edge = "<->", to = "c"),
    data.frame(from = "b", edge = "-->", to = "d"),
    data.frame(from = "c", edge = "-->", to = "d")
  )

  cg_ag <- as_caugi(M, class = "AG")
  expect_identical(cg_ag@graph_class, "AG")
  expect_equal(
    ord(as.data.frame(edges(cg_ag))[c("from", "edge", "to")]),
    ord(exp)
  )

  # A {0, 2, 3} matrix is decoded by endpoint marks whatever class is asked
  # for, so the requested class must not change the decoding. (This block used
  # `class = "PAG"`; a MAG is generally *not* a valid PAG, and `class = "PAG"`
  # now runs the complete PAG check, so a second non-PAG class is used here.)
  cg_unknown <- as_caugi(M, class = "UNKNOWN")
  expect_identical(cg_unknown@graph_class, "UNKNOWN")
  expect_equal(
    ord(as.data.frame(edges(cg_unknown))[c("from", "edge", "to")]),
    ord(exp)
  )
})

test_that("decoded marks are validated against the requested class", {
  nm <- c("A", "B")
  M <- matrix(0L, 2, 2, dimnames = list(nm, nm))
  M["A", "B"] <- 2L # A <-> B
  M["B", "A"] <- 2L

  expect_error(as_caugi(M, class = "DAG"))
})

test_that("0/1 matrices keep adjacency semantics for non-PAG classes", {
  nm <- c("A", "B", "C")
  m <- matrix(0L, 3, 3, dimnames = list(nm, nm))
  m["A", "B"] <- 1L
  m["B", "C"] <- 1L

  cg <- as_caugi(m, class = "DAG")
  expect_identical(cg@graph_class, "DAG")

  e <- as.data.frame(edges(cg))
  expect_true(all(e$edge == "-->"))
  expect_setequal(paste(e$from, e$to), c("A B", "B C"))
})

test_that("out-of-range matrix codes error", {
  nm <- c("A", "B")
  m <- matrix(0L, 2, 2, dimnames = list(nm, nm))
  m["A", "B"] <- 5L

  expect_error(
    as_caugi(m, class = "AG"),
    "Only either 0:1 are allowed or 0,2,3"
  )
  expect_error(as_caugi(m, class = "PAG"), "integer codes 0-3", fixed = TRUE)

  # One-sided mark: an endpoint pair that is not a valid edge.
  m2 <- matrix(0L, 2, 2, dimnames = list(nm, nm))
  m2["A", "B"] <- 2L
  expect_error(
    as_caugi(m2, class = "AG"),
    "Unsupported endpoint marks between A and B"
  )
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

test_that("tidygraph interface to igraph", {
  skip_if_not_installed("tidygraph")
  tg <- tidygraph::create_path(3)
  adj_matrix <- rbind(tg[1], tg[2], tg[3])
  cg <- as_caugi(tg, class = "PDAG")
  expect_equal(
    unname(as_adjacency(cg)),
    unname(adj_matrix)
  )
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
  cg <- as_caugi(g, class = "DAG")

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
  # This test is about the dagitty edge codes mapping to the right glyphs; the
  # class is incidental, and `A o-> B` on its own is not a valid PAG.
  cg <- as_caugi(g, class = "UNKNOWN")

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

test_that("dagitty -> caugi: PAG class is preserved", {
  skip_if_not_installed("dagitty")
  # `A o-> C <-o B` with A, B non-adjacent: the PAG of the collider
  # `A --> C <-- B`, and a genuinely valid PAG (a lone edge never is).
  g <- dagitty::dagitty("pag { A @-> C ; B @-> C }")
  cg <- as_caugi(g, class = "PAG")

  # graph_class getter returns uppercase from Rust; compare in upper
  expect_identical(toupper(cg@graph_class), "PAG")
  expect_true(any(cg@edges$edge == "o->"))
})

test_that("dagitty -> caugi: respects `simple` flag and builds session", {
  skip_if_not_installed("dagitty")
  g <- dagitty::dagitty("dag { A -> B }")
  cg <- as_caugi(g, class = "DAG", simple = TRUE)

  expect_true(!is.null(cg@session))
  expect_true(isTRUE(cg@simple))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── bnlearn conversion ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("bnlearn bn: isolates only", {
  skip_if_not_installed("bnlearn")
  g <- bnlearn::empty.graph(nodes = c("A", "B", "C"))
  cg <- as_caugi(g, class = "DAG")
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

test_that("as_caugi with bnlearn with both directed and undirected edges and collapse = TRUE", {
  skip_if_not_installed("igraph")
  skip_if_not_installed("bnlearn")

  nodes <- c("x", "v", "w", "z", "s")

  bn <- bnlearn::empty.graph(nodes)
  bnlearn::arcs(bn) <- matrix(
    c(
      "x",
      "v",
      "x",
      "w",
      "v",
      "x",
      "v",
      "z",
      "w",
      "x",
      "w",
      "z",
      "z",
      "s"
    ),
    ncol = 2,
    byrow = TRUE,
    dimnames = list(NULL, c("from", "to"))
  )

  cg <- as_caugi(bn, class = "PDAG", collapse = TRUE)

  actual <- edges(cg)

  expected <- data.table::data.table(
    from = c("v", "v", "w", "w", "z"),
    edge = c("---", "-->", "---", "-->", "-->"),
    to = c("x", "z", "x", "z", "s")
  )

  data.table::setorder(actual, from, to, edge)
  data.table::setorder(expected, from, to, edge)

  expect_identical(actual, expected)
})

test_that("integer matrix dead and error branches are covered", {
  expect_error(as_caugi(1L), "`x` must be a matrix.")
  expect_error(as_caugi(1.0), "`x` must be a matrix.")
  expect_error(as_caugi(TRUE), "`x` must be a matrix.")

  m_bad_pag <- matrix(c(0L, 4L, 0L, 0L), 2, 2)
  expect_error(
    as_caugi(m_bad_pag, class = "PAG"),
    "integer codes 0-3"
  )

  # Force dispatch to integer method with non-integer payloads.
  m_logical <- matrix(FALSE, 2, 2)
  class(m_logical) <- c("integer", "matrix")
  expect_error(
    as_caugi(m_logical, class = "PAG"),
    "PAG class is not supported for logical matrices."
  )

  m_double <- matrix(0.5, 1, 1)
  class(m_double) <- c("integer", "matrix")
  expect_error(
    as_caugi(m_double, class = "DAG"),
    "non-negative integer matrix"
  )

  m_character <- matrix("a", 1, 1)
  class(m_character) <- c("integer", "matrix")
  expect_error(
    as_caugi(m_character, class = "DAG"),
    "logical or numeric matrix"
  )

  # Trigger mark_sym() default branch with a one-sided PAG code.
  m_bad_switch <- matrix(0L, 2, 2)
  m_bad_switch[1, 2] <- 1L
  expect_error(
    as_caugi(m_bad_switch, class = "PAG"),
    "Unsupported endpoint marks"
  )
})

test_that("PAG normalization swap branches are covered", {
  # The swap branches live in the mark decoder and fire when the arrowhead /
  # circle sits at the *earlier* node of a matrix pair. Circle marks force
  # `class = "PAG"`, which now runs the complete PAG check, so the branches are
  # exercised with two genuinely valid PAGs whose node order (dimnames) puts
  # the relevant endpoints the wrong way round.

  # Swap branch 1 (arrow/tail  => j --> i) via D --> B, and
  # swap branch 3 (arrow/circle => j o-> i) via C o-> D.
  nm1 <- c("B", "D", "C", "A", "E")
  m1 <- matrix(0L, 5, 5, dimnames = list(nm1, nm1))
  m1["B", "D"] <- 3L # mark at D end  => D --> B  (branch 1)
  m1["D", "B"] <- 2L # mark at B end
  m1["D", "C"] <- 1L #                => C o-> D  (branch 3)
  m1["C", "D"] <- 2L
  m1["A", "B"] <- 2L #                => A <-> B
  m1["B", "A"] <- 2L
  m1["A", "D"] <- 2L #                => A <-> D
  m1["D", "A"] <- 2L
  m1["C", "E"] <- 1L #                => C o-o E
  m1["E", "C"] <- 1L

  e1 <- edges(as_caugi(m1, class = "PAG"))
  expect_true(any(e1$from == "D" & e1$edge == "-->" & e1$to == "B"))
  expect_true(any(e1$from == "C" & e1$edge == "o->" & e1$to == "D"))

  # Swap branch 2 (circle/tail => j --o i) via A --o E.
  nm2 <- c("E", "B", "C", "D", "A")
  m2 <- matrix(0L, 5, 5, dimnames = list(nm2, nm2))
  m2["E", "A"] <- 3L # mark at A end  => A --o E  (branch 2)
  m2["A", "E"] <- 1L # mark at E end
  m2["A", "C"] <- 3L #                => A --- C
  m2["C", "A"] <- 3L
  m2["A", "D"] <- 3L #                => A --- D
  m2["D", "A"] <- 3L
  m2["B", "C"] <- 3L #                => B --- C
  m2["C", "B"] <- 3L
  m2["B", "D"] <- 3L #                => B --- D
  m2["D", "B"] <- 3L

  e2 <- edges(as_caugi(m2, class = "PAG"))
  expect_true(any(e2$from == "A" & e2$edge == "--o" & e2$to == "E"))
})

test_that("class-specific branches for optional backends are covered", {
  skip_if_not_installed("igraph")
  skip_if_not_installed("graph")
  skip_if_not_installed("dagitty")
  skip_if_not_installed("bnlearn")

  g_ig <- igraph::graph_from_edgelist(
    matrix(c("A", "B"), ncol = 2),
    directed = TRUE
  )
  expect_error(
    as_caugi(g_ig, class = "PAG"),
    "PAG class is not supported for igraph objects."
  )

  g_graphnel <- graph::graphNEL(nodes = c("A", "B"), edgemode = "directed")
  g_graphnel <- graph::addEdge("A", "B", g_graphnel)
  methods::slot(g_graphnel, "nodes", check = FALSE) <- NULL
  cg_graphnel <- as_caugi(g_graphnel, class = "DAG")
  expect_setequal(cg_graphnel@nodes$name, c("V1", "V2"))

  expect_error(as_caugi(1.0), "`x` must be a matrix.")
  expect_error(as_caugi(TRUE), "`x` must be a matrix.")

  obj_tidy <- structure(list(), class = "tidygraph")
  expect_error(
    as_caugi(obj_tidy, class = "PAG"),
    "PAG class is not supported for tidygraph objects."
  )

  g_dagitty <- dagitty::dagitty("dag { A -> B }")
  expect_error(
    testthat::with_mocked_bindings(
      as_caugi(g_dagitty, class = "DAG"),
      edges = function(x) {
        data.frame(v = "A", w = "B", e = "bad", stringsAsFactors = FALSE)
      },
      .package = "dagitty"
    ),
    "Unsupported dagitty edge code"
  )

  bn <- bnlearn::empty.graph(nodes = c("A", "B"))
  expect_error(
    as_caugi(bn, class = "PAG"),
    "PAG class is not supported for bnlearn objects."
  )
})
