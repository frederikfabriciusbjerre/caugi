test_that("to_dot works with simple DAG", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  dot <- to_dot(cg)

  expect_s7_class(dot, caugi_dot)
  dot_str <- as.character(dot)
  expect_match(dot_str, "digraph")
  expect_match(dot_str, "A -> B")
  expect_match(dot_str, "A -> C")
  expect_match(dot_str, "B -> D")
  expect_match(dot_str, "C -> D")
})

test_that("to_dot handles different edge types", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %o->% E
  )

  dot <- to_dot(cg)

  expect_match(as.character(dot), "A -> B;")
  expect_match(as.character(dot), 'C -> D \\[dir="both"\\]')
  expect_match(as.character(dot), 'D -> E \\[dir="both", arrowtail="odot"\\]')
})

test_that("to_dot escapes special characters", {
  cg <- caugi(
    "Node 1" %-->% "Node-2",
    "Node-2" %-->% "Node_3"
  )

  dot <- to_dot(cg)

  expect_match(as.character(dot), '"Node 1"')
  expect_match(as.character(dot), '"Node-2"')
  expect_match(as.character(dot), "Node_3") # No quotes needed for valid identifier
})

test_that("to_dot accepts graph attributes", {
  cg <- caugi(A %-->% B, class = "DAG")

  dot <- to_dot(
    cg,
    graph_attrs = list(rankdir = "LR"),
    node_attrs = list(shape = "box"),
    edge_attrs = list(color = "blue")
  )

  expect_match(as.character(dot), 'rankdir="LR"')
  expect_match(as.character(dot), 'node \\[shape="box"\\]')
  expect_match(as.character(dot), 'edge \\[color="blue"\\]')
})

test_that("to_dot works with single node", {
  cg <- caugi(A, class = "DAG")

  dot <- to_dot(cg)

  expect_match(as.character(dot), "graph") # No edges, so uses "graph"
  expect_match(as.character(dot), "A;")
})

test_that("to_dot builds graph if needed", {
  cg <- caugi(A %-->% B, build = FALSE)

  dot <- to_dot(cg)

  expect_s7_class(dot, caugi_dot)
  expect_match(as.character(dot), "A -> B")
})

test_that("write_dot creates file", {
  cg <- caugi(A %-->% B, class = "DAG")

  tmp <- tempfile(fileext = ".dot")
  result <- write_dot(cg, tmp)

  expect_true(file.exists(tmp))
  expect_equal(result, tmp)

  content <- readLines(tmp)
  expect_match(paste(content, collapse = "\n"), "A -> B")

  unlink(tmp)
})

test_that("write_dot accepts attributes", {
  cg <- caugi(A %-->% B, class = "DAG")

  tmp <- tempfile(fileext = ".dot")
  write_dot(cg, tmp, graph_attrs = list(rankdir = "LR"))

  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, 'rankdir="LR"')

  unlink(tmp)
})

test_that("to_dot handles empty graph", {
  cg <- caugi(A + B + C, class = "DAG")

  dot <- to_dot(cg)

  expect_match(as.character(dot), "A;")
  expect_match(as.character(dot), "B;")
  expect_match(as.character(dot), "C;")
  # Should have no edges section or empty
})

test_that("to_dot chooses graph type correctly", {
  # Only undirected edges -> graph
  cg_und <- caugi(A %---% B)
  dot_und <- to_dot(cg_und)
  expect_match(as.character(dot_und), "^graph ")

  # Has directed edges -> digraph
  cg_dir <- caugi(A %-->% B)
  dot_dir <- to_dot(cg_dir)
  expect_match(as.character(dot_dir), "^digraph ")

  # Mixed graphs -> digraph
  cg_mixed <- caugi(A %-->% B, B %---% C)
  dot_mixed <- to_dot(cg_mixed)
  expect_match(as.character(dot_mixed), "^digraph ")
})
