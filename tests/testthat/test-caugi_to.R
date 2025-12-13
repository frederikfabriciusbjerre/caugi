# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────────── igraph ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("cg --> as_igraph --> as_caugi --> as_igraph works for directed", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    E %-->% F,
    class = "DAG"
  )

  ig <- as_igraph(cg)
  cg2 <- as_caugi(ig, class = "DAG")

  ig2 <- as_igraph(cg2)
  expect_equal(igraph::V(ig)$name, igraph::V(ig2)$name)
  expect_equal(igraph::as_data_frame(ig), igraph::as_data_frame(ig2))
  expect_equal(nodes(cg), nodes(cg2))
  expect_equal(edges(cg), edges(cg2))
})

test_that("errors on non-caugi input", {
  expect_error(as_igraph("not-a-caugi"))
})


test_that("Unknown graph with undirected edges become undirected igraph", {
  cg <- caugi(A %---% B + C, C %---% D, class = "Unknown")
  ig <- as_igraph(cg)
  expect_false(igraph::is_directed(ig))
})

test_that("Unknown with PAG edges fails", {
  cg <- caugi(A %o-o% B %o->% C, class = "Unknown")
  expect_error(as_igraph(cg))
})

test_that("empty graph handled with given vertices", {
  # Only nodes, no edges
  cg <- caugi(A, B, C, class = "DAG")
  ig <- as_igraph(cg)
  expect_true(all(sort(igraph::V(ig)$name) == sort(nodes(cg)$name)))
  expect_equal(nrow(igraph::as_data_frame(ig)), 0L)
  # Directedness defaults to FALSE when no edge types present
  expect_false(igraph::is_directed(ig))
})

test_that("all undirected edge types yield undirected igraph", {
  cg <- caugi(A %---% B %<->% C, class = "Unknown")
  ig <- as_igraph(cg)
  expect_false(igraph::is_directed(ig))
  ed <- igraph::as_data_frame(ig)
  # undirected collapsed
  expect_true(
    any(ed$from == "A" & ed$to == "B") || any(ed$from == "B" & ed$to == "A")
  )
  expect_true(
    any(ed$from == "B" & ed$to == "C") || any(ed$from == "C" & ed$to == "B")
  )
  # no duplicates
  expect_equal(nrow(ed), 2L)
})

test_that("all directed edges yield directed igraph", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% C,
    class = "DAG"
  )
  ig <- as_igraph(cg)
  expect_true(igraph::is_directed(ig))
  ed <- igraph::as_data_frame(ig)
  expect_true(all(ed$from %in% c("A", "B", "D")))
  expect_true(all(ed$to %in% c("B", "C")))
  expect_equal(nrow(ed), 3L)
})

test_that("mixed edges: directed kept, undirected duplicated as bidirected", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %---% D,
    class = "PDAG"
  )
  ig <- as_igraph(cg)
  expect_true(igraph::is_directed(ig))
  ed <- igraph::as_data_frame(ig)
  # A->B remains single
  expect_true(any(ed$from == "A" & ed$to == "B"))
  # B---C becomes B->C and C->B
  expect_true(any(ed$from == "B" & ed$to == "C"))
  expect_true(any(ed$from == "C" & ed$to == "B"))
  # C<->D becomes C->D and D->C
  expect_true(any(ed$from == "C" & ed$to == "D"))
  expect_true(any(ed$from == "D" & ed$to == "C"))
  # total edges: 1 directed + 2*undirected (2 undirected edges) = 5
  expect_equal(nrow(ed), 5L)
})

test_that("conversion from UG --> igraph works", {
  cg <- caugi(A %---% B, class = "UG")
  ig <- as_igraph(cg)

  expect_false(igraph::is_directed(ig))
  ed <- igraph::as_data_frame(ig)
  expect_true(
    any(ed$from == "A" & ed$to == "B") || any(ed$from == "B" & ed$to == "A")
  )
  expect_equal(nrow(ed), 1L)
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Adjacency ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("cg --> adj --> cg --> adj round-trip (DAG)", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    E, # isolated node carried via names
    class = "DAG"
  )

  adj <- as_adjacency(cg)
  cg2 <- as_caugi(adj, class = "DAG")
  adj2 <- as_adjacency(cg2)

  expect_identical(rownames(adj), rownames(adj2))
  expect_identical(colnames(adj), colnames(adj2))
  expect_identical(adj, adj2)

  expect_equal(nodes(cg), nodes(cg2))
  expect_equal(
    edges(cg),
    edges(cg2)
  )
})

test_that("cg --> adj (PDAG)", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %---% D,
    E, # isolated node carried via names
    class = "PDAG"
  )

  adj <- as_adjacency(cg)
  expect_identical(adj["A", "B"], 1L)
  expect_identical(adj["A", "C"], 1L)
  expect_identical(adj["B", "D"], 1L)
  expect_identical(adj["C", "D"], 1L)
  expect_identical(adj["D", "C"], 1L)
  expect_identical(adj["E", "E"], 0L)
})

test_that("as_adjacency errors on non-caugi input", {
  expect_error(as_adjacency("not-a-caugi"))
})

test_that("as_adjacency returns 0-matrix for nodes-only graph", {
  cg <- caugi(A, B, C, class = "DAG")
  adj <- as_adjacency(cg)
  expect_identical(dimnames(adj), list(c("A", "B", "C"), c("A", "B", "C")))
  expect_true(all(adj == 0L))
})

test_that("as_adjacency errors on unsupported glyphs", {
  # Bidirected edges are now supported (for ADMG)
  cg1 <- caugi(A %<->% B, class = "UNKNOWN")
  adj1 <- as_adjacency(cg1)
  expect_equal(adj1["A", "B"], 1L)
  expect_equal(adj1["B", "A"], 1L) # symmetric

  # Partial edges (o->) are not supported
  cg2 <- caugi(A %o->% B, class = "UNKNOWN")
  expect_error(as_adjacency(cg2), "Unsupported edge glyphs")
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── bnlearn ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("cg -> bn -> cg -> bn round-trip (DAG)", {
  testthat::skip_if_not_installed("bnlearn")

  cg <- caugi(
    A %-->% B + C,
    D %-->% C,
    class = "DAG"
  )

  bn <- as_bnlearn(cg)
  cg2 <- as_caugi(bn, class = "DAG")
  bn2 <- as_bnlearn(cg2)

  # nodes
  expect_setequal(bnlearn::nodes(bn), bnlearn::nodes(bn2))

  # arcs as sets
  ord <- function(m) m[do.call(order, as.data.frame(m)), , drop = FALSE]
  expect_identical(ord(bnlearn::arcs(bn)), ord(bnlearn::arcs(bn2)))

  # also check cg equality
  expect_equal(nodes(cg), nodes(cg2))
  expect_equal(
    edges(cg),
    edges(cg2)
  )
})

test_that("as_bnlearn errors for non-DAG or non-directed", {
  testthat::skip_if_not_installed("bnlearn")
  expect_error(as_bnlearn(caugi(A %---% B, class = "UNKNOWN")))
  expect_error(as_bnlearn("not-a-caugi"))
})

test_that("as_bnlearn returns empty DAG when no arcs", {
  testthat::skip_if_not_installed("bnlearn")
  cg <- caugi(A, B, C, class = "DAG")
  bn <- as_bnlearn(cg)
  expect_setequal(bnlearn::nodes(bn), c("A", "B", "C"))
  expect_identical(nrow(bnlearn::arcs(bn)), 0L)
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── dagitty ────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("cg --> dagitty --> cg --> dagitty round-trip", {
  testthat::skip_if_not_installed("dagitty")

  cg <- caugi(
    A %-->% B,
    B %<->% C,
    D %---% E,
    F %o->% G,
    H %o-o% I,
    J, # isolated
    class = "UNKNOWN",
    nodes = c("A", "B", "C", "D", "E", "F", "G", "H", "I", "J")
  )

  dg <- as_dagitty(cg)
  cg2 <- as_caugi(dg, class = "UNKNOWN")
  dg2 <- as_dagitty(cg2)

  # Compare edges as sets using dagitty::edges()
  ed1 <- as.data.frame(dagitty::edges(dg), stringsAsFactors = FALSE)
  ed2 <- as.data.frame(dagitty::edges(dg2), stringsAsFactors = FALSE)

  ord <- function(dd) dd[do.call(order, dd), , drop = FALSE]
  expect_identical(ord(ed1), ord(ed2))

  # Nodes preserved including isolates
  expect_setequal(names(dg), names(dg2))

  # Also check caugi equality
  expect_equal(nodes(cg), nodes(cg2))
  expect_equal(nodes(cg), nodes(cg2))
})

test_that("as_dagitty errors on non-caugi input", {
  testthat::skip_if_not_installed("dagitty")
  expect_error(as_dagitty("not-a-caugi"))
})

test_that("as_dagitty preserves isolates for empty edge set", {
  testthat::skip_if_not_installed("dagitty")
  cg <- caugi(A, B, C, class = "DAG")
  dg <- as_dagitty(cg)
  expect_setequal(names(dg), c("A", "B", "C"))
  expect_identical(nrow(as.data.frame(dagitty::edges(dg))), 0L)
})

test_that("as_dagitty picks dag type for only directed edges", {
  testthat::skip_if_not_installed("dagitty")
  cg <- caugi(A %-->% B, class = "DAG")
  dg <- as_dagitty(cg)
  gt <- get("graphType", asNamespace("dagitty"))
  expect_identical(gt(dg), "dag")
})

test_that("as_dagitty picks pdag for --> and ---", {
  testthat::skip_if_not_installed("dagitty")
  cg <- caugi(A %-->% B, B %---% C, class = "PDAG")
  dg <- as_dagitty(cg)
  gt <- get("graphType", asNamespace("dagitty"))
  expect_identical(gt(dg), "pdag")
})

test_that("as_dagitty picks mag for --> and <->", {
  testthat::skip_if_not_installed("dagitty")
  cg <- caugi(A %-->% B, B %<->% C, class = "UNKNOWN")
  dg <- as_dagitty(cg)
  gt <- get("graphType", asNamespace("dagitty"))
  expect_identical(gt(dg), "mag")
})

test_that("as_dagitty picks pag when any circle endpoints present", {
  testthat::skip_if_not_installed("dagitty")
  cg <- caugi(A %o->% B, class = "UNKNOWN")
  dg <- as_dagitty(cg)
  gt <- get("graphType", asNamespace("dagitty"))
  expect_identical(gt(dg), "pag")
})

test_that("as_dagitty encodes circle endpoints with @ in edges()", {
  testthat::skip_if_not_installed("dagitty")
  cg <- caugi(
    A %o->% B,
    C %o-o% D,
    E %--o% F,
    class = "UNKNOWN"
  )
  dg <- as_dagitty(cg)
  ed <- as.data.frame(dagitty::edges(dg), stringsAsFactors = FALSE)$e
  # Expect at least one @->, one @-@, and one @-- code present
  expect_true(any(grepl("@->", ed, fixed = TRUE)))
  expect_true(any(grepl("@-@", ed, fixed = TRUE)))
  expect_true(any(grepl("@--", ed, fixed = TRUE)))
})

test_that("as_dagitty errors on unsupported edge types", {
  testthat::skip_if_not_installed("dagitty")
  reset_caugi_registry()
  reg <- caugi_registry()
  register_caugi_edge(
    glyph = "<--",
    tail_mark = "arrow",
    head_mark = "tail",
    class = "directed",
    symmetric = FALSE
  )
  cg1 <- caugi(A %<--% B, class = "UNKNOWN")
  expect_error(as_dagitty(cg1), "Unsupported edge type for dagitty")
  reset_caugi_registry()
})
