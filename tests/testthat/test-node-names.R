# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Node names ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

expect_name_warning <- function(object) {
  expect_warning(object, class = "caugi_deprecated_node_names")
}

# NA and "" already error as edge endpoints, so they are only declared as
# isolated nodes; control characters are also used in edges.
bad_names <- c(NA, "", "a\tb", "a\nb")
ctrl_names <- c("a\tb", "a\nb", "a\rb", "a\001b")

test_that("bad node names warn from caugi()", {
  for (nm in bad_names) {
    expect_name_warning(caugi(nodes = c("A", nm)))
    expect_name_warning(caugi(A %-->% B, nodes = nm))
    expect_name_warning(eval(bquote(caugi(A %-->% B, .(nm)))))
  }
  # a row with `edge = NA` declares `from` as an isolated node
  for (nm in setdiff(bad_names, NA)) {
    expect_name_warning(caugi(
      from = c("A", nm),
      edge = c("-->", NA),
      to = c("B", NA)
    ))
    expect_name_warning(caugi(
      edges_df = data.frame(
        from = c("A", nm),
        edge = c("-->", NA),
        to = c("B", NA)
      )
    ))
  }
  for (nm in ctrl_names) {
    expect_name_warning(eval(bquote(caugi(.(nm) %-->% B))))
    expect_name_warning(caugi(from = "A", edge = "-->", to = nm))
    expect_name_warning(caugi(
      edges_df = data.frame(from = nm, edge = "-->", to = "B")
    ))
  }
})

test_that("bad node names warn from add_nodes(), add_edges() and set_edges()", {
  cg <- caugi(A %-->% B, class = "UNKNOWN")
  for (nm in bad_names) {
    expect_name_warning(add_nodes(cg, name = nm))
    expect_name_warning(eval(bquote(add_nodes(cg, .(nm)))))
  }
  for (nm in ctrl_names) {
    expect_name_warning(add_edges(cg, from = nm, edge = "-->", to = "A"))
    expect_name_warning(eval(bquote(add_edges(cg, A %-->% .(nm)))))
    expect_name_warning(set_edges(cg, from = "A", edge = "---", to = nm))
    expect_name_warning(eval(bquote(set_edges(cg, .(nm) %---% B))))
  }
})

test_that("bad node names warn from as_caugi()", {
  for (nm in bad_names) {
    m <- matrix(0L, 3, 3, dimnames = list(c("A", "B", nm), c("A", "B", nm)))
    m[1, 2] <- 1L
    expect_name_warning(as_caugi(m))
    expect_name_warning(as_caugi(m == 1L))
    expect_name_warning(as_caugi(m + 0))
  }
  m <- matrix(c(0L, 0L, 1L, 0L), 2, dimnames = list(ctrl_names[1:2], NULL))
  expect_name_warning(as_caugi(m))

  skip_if_not_installed("igraph")
  for (nm in bad_names) {
    g <- igraph::make_empty_graph(3)
    igraph::V(g)$name <- c("A", "B", nm)
    g <- igraph::add_edges(g, c("A", "B"))
    expect_name_warning(as_caugi(g))
  }
  g <- igraph::make_graph(c("A", "a\tb"), directed = TRUE)
  expect_name_warning(as_caugi(g))
})

test_that("bad node names warn from as_caugi() for other packages' graphs", {
  skip_if_not_installed("Matrix")
  m <- Matrix::Matrix(
    matrix(c(0L, 0L, 1L, 0L), 2, dimnames = list(c("A", "a\tb"), NULL))
  )
  expect_name_warning(as_caugi(m))

  skip_if_not_installed("graph")
  gn <- graph::graphNEL(
    nodes = c("A", "a\tb"),
    edgeL = list(A = "a\tb", "a\tb" = character()),
    edgemode = "directed"
  )
  expect_name_warning(as_caugi(gn))

  skip_if_not_installed("bnlearn")
  bn <- bnlearn::empty.graph(c("A", "a\tb"))
  bnlearn::arcs(bn) <- matrix(
    c("A", "a\tb"),
    1,
    dimnames = list(NULL, c("from", "to"))
  )
  expect_name_warning(as_caugi(bn))
  expect_name_warning(as_caugi(bnlearn::empty.graph(c("A", ""))))
})

test_that("bad node names warn when reading graphs", {
  cg <- suppressWarnings(caugi(A %-->% "a\tb", class = "DAG"))

  expect_name_warning(caugi_deserialize(caugi_serialize(cg)))

  path <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(path), add = TRUE)
  write_caugi(cg, path)
  expect_name_warning(read_caugi(path))

  # write_graphml() writes the tab raw, which XML reads back as a space, so
  # write the GraphML by hand with an escaped tab.
  graphml <- tempfile(fileext = ".graphml")
  on.exit(unlink(graphml), add = TRUE)
  writeLines(
    c(
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">",
      "<graph id=\"G\" edgedefault=\"directed\">",
      "<node id=\"A\"/>",
      "<node id=\"a&#9;b\"/>",
      "</graph>",
      "</graphml>"
    ),
    graphml
  )
  expect_name_warning(cg2 <- read_graphml(graphml))
  expect_identical(cg2@nodes$name, c("A", "a\tb"))
})

test_that("bad node names are kept as before, with a classed warning", {
  expect_warning(
    cg <- caugi(A %-->% B, nodes = c("A", "B", NA, "", "a\tb")),
    'will be an error in a future version of caugi: NA, "", "a\\tb".',
    fixed = TRUE
  )
  expect_identical(cg@nodes$name, c("A", "B", "NA", "", "a\tb"))
  expect_warning(
    add_nodes(caugi(A), name = NA),
    class = "deprecatedWarning"
  )

  # Only the incoming names are checked: removing a bad node does not warn,
  # nor does adding a good node to a graph that has one.
  expect_no_warning(remove_nodes(cg, name = "a\tb"))
  expect_no_warning(add_nodes(cg, name = "C"))
})

test_that("valid node names give no warning", {
  utf8 <- enc2utf8(`Encoding<-`("caf\xe9", "latin1"))
  nm <- c("A", "B", "node with spaces", "1", utf8)

  expect_no_warning(cg <- caugi(A %-->% B, nodes = nm))
  expect_no_warning(caugi(from = nm[-1], edge = rep("-->", 4), to = nm[-5]))
  expect_no_warning(add_nodes(cg, name = "C"))
  expect_no_warning(add_edges(cg, from = utf8, edge = "-->", to = "C"))
  expect_no_warning(set_edges(cg, from = utf8, edge = "-->", to = "C"))

  m <- matrix(0L, 2, 2, dimnames = list(c("A", utf8), c("A", utf8)))
  expect_no_warning(as_caugi(m))
})

test_that("latin1 node names are stored as UTF-8 and found by queries", {
  latin1 <- `Encoding<-`("caf\xe9", "latin1")
  utf8 <- enc2utf8(latin1)

  check <- function(cg) {
    expect_true(all(validUTF8(cg@nodes$name)))
    expect_true(utf8 %in% cg@nodes$name)
    expect_identical(sum(cg@nodes$name == utf8), 1L)
    expect_identical(children(cg, latin1), "B")
    expect_identical(children(cg, utf8), "B")
    expect_identical(parents(cg, "B"), utf8)
    expect_identical(subgraph(cg, c(latin1, "B"))@nodes$name, c(utf8, "B"))
  }

  check(caugi(from = latin1, edge = "-->", to = "B", class = "DAG"))
  check(caugi(edges_df = data.frame(from = latin1, edge = "-->", to = "B")))
  check(
    caugi(nodes = c(latin1, "B"), class = "DAG") |>
      add_edges(from = latin1, edge = "-->", to = "B")
  )
  check(
    caugi(B, class = "DAG") |>
      add_nodes(name = latin1) |>
      add_edges(from = utf8, edge = "-->", to = "B")
  )
  check(
    caugi(A %-->% B, class = "DAG") |>
      set_edges(from = latin1, edge = "-->", to = "B") |>
      remove_nodes(name = "A")
  )

  m <- matrix(c(0L, 0L, 1L, 0L), 2, dimnames = list(c(latin1, "B"), NULL))
  check(as_caugi(m, class = "DAG"))

  # Adding an existing edge with the latin1 name does not duplicate it.
  cg <- caugi(from = utf8, edge = "-->", to = "B", class = "DAG")
  expect_identical(
    nrow(add_edges(cg, from = latin1, edge = "-->", to = "B")@edges),
    1L
  )

  cg <- remove_edges(cg, from = latin1, to = "B")
  expect_identical(nrow(cg@edges), 0L)
})
