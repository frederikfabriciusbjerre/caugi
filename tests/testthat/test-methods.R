test_that("print method works for empty graph", {
  cg <- caugi(class = "DAG")
  output <- capture.output(print(cg))

  expect_true(any(grepl("0 nodes, 0 edges", output, fixed = TRUE)))
  expect_true(any(grepl("nodes: (none)", output, fixed = TRUE)))
  expect_true(any(grepl("edges: (none)", output, fixed = TRUE)))
})

test_that("print method works for simple graph", {
  cg <- caugi(A %-->% B, class = "DAG")
  output <- capture.output(print(cg))

  expect_true(any(grepl("2 nodes, 1 edges", output, fixed = TRUE)))
  expect_true(any(grepl("graph_class: DAG", output, fixed = TRUE)))
  expect_true(any(grepl("A", output, fixed = TRUE)))
  expect_true(any(grepl("B", output, fixed = TRUE)))
  expect_true(any(grepl("A-->B", output, fixed = TRUE)))
})

test_that("print method works for larger graph", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D + E,
    class = "DAG"
  )
  output <- capture.output(print(cg))

  expect_true(any(grepl("5 nodes, 5 edges", output, fixed = TRUE)))
  expect_true(any(grepl("A", output, fixed = TRUE)))
  expect_true(any(grepl("D", output, fixed = TRUE)))
})

test_that("print method respects max_nodes", {
  cg <- caugi(
    A %-->% B + C + D + E + G,
    class = "DAG"
  )
  output <- capture.output(print(cg, max_nodes = 2))

  expect_true(any(grepl("nodes more", output, fixed = TRUE)))
})

test_that("print method with many edges shows truncation", {
  # Create a graph with enough edges to trigger automatic truncation
  cg <- caugi(
    A %-->% B + C + D + E + G + H + I + J + K + L + M + N + O + P + Q,
    B %-->% C + D + E + G + H + I + J + K + L + M + N + O + P + Q,
    C %-->% D + E + G + H + I + J + K + L + M + N + O + P + Q,
    class = "DAG"
  )
  output <- capture.output(print(cg))

  # Should show truncation message when there are many edges
  expect_true(any(grepl("edges more", output, fixed = TRUE)))
})

test_that("print method shows simple status", {
  cg <- caugi(A %-->% B, class = "DAG")
  output <- capture.output(print(cg))
  expect_true(any(grepl("simple: TRUE", output, fixed = TRUE)))
})

test_that("print method returns object invisibly", {
  cg <- caugi(A %-->% B, class = "DAG")
  result <- withVisible(print(cg))

  expect_false(result$visible)
  expect_s7_class(result$value, caugi)
})

test_that("length method works", {
  cg <- caugi(A %-->% B + C, class = "DAG")
  expect_equal(length(cg), 3)

  cg_empty <- caugi(class = "DAG")
  expect_equal(length(cg_empty), 0)

  cg_nodes <- caugi(nodes = LETTERS[1:10], class = "DAG")
  expect_equal(length(cg_nodes), 10)
})

test_that("print defensive and helper branches are covered", {
  cg <- caugi(A %-->% B %-->% C, class = "DAG")

  # Exercise print() fallback for malformed objects without a session.
  bad <- cg
  attr(bad, "session") <- NULL
  out_bad <- capture.output(print(bad))
  expect_true(any(grepl("session=NULL", out_bad, fixed = TRUE)))
  expect_true(any(grepl("graph_class: NA", out_bad, fixed = TRUE)))

  # Exercise session formatting fallback branch (no hex pointer pattern).
  out_fmt <- testthat::with_mocked_bindings(
    capture.output(print(cg)),
    format = function(x, ...) "session_text",
    .package = "base"
  )
  expect_true(any(grepl("session=session_text", out_fmt, fixed = TRUE)))

  # Exercise n_fit < 1 guards in both node and edge printing.
  out_fit <- testthat::with_mocked_bindings(
    capture.output(print(cg)),
    .caugi_fit_on_line = function(...) 0L,
    .package = "caugi"
  )
  expect_true(length(out_fit) > 0L)

  # Exercise max_edges branch where edge_labels becomes empty.
  out_edges <- capture.output(print(cg, max_edges = 0))
  expect_true(any(grepl("edges: (none)", out_edges, fixed = TRUE)))

  expect_identical(
    caugi:::.caugi_fit_on_line(character(), width = 80, indent = 2),
    0L
  )
})

test_that("compare_proxy and all.equal branches are covered", {
  proxy_fun <- caugi:::`compare_proxy.caugi::caugi`
  eq_fun <- caugi:::`all.equal.caugi::caugi`

  cg <- caugi(
    from = c("B", "A"),
    edge = c("-->", "-->"),
    to = c("C", "B"),
    nodes = c("A", "B", "C"),
    class = "DAG"
  )
  proxy <- proxy_fun(cg, path = "cg")
  expect_true(is.list(proxy$object))
  expect_identical(proxy$path, "cg")

  expect_match(eq_fun(cg, list()), "current is not a caugi object")

  cg_simple <- caugi(A %-->% B, class = "DAG")
  cg_non_simple <- caugi(A %-->% B, class = "UNKNOWN", simple = FALSE)
  diff_simple <- eq_fun(cg_simple, cg_non_simple)
  expect_true(any(grepl("^simple:", diff_simple)))
  expect_true(any(grepl("^graph_class:", diff_simple)))

  cg_nodes2 <- caugi(A %-->% B, C, class = "DAG")
  diff_nodes <- eq_fun(cg_simple, cg_nodes2)
  expect_true(any(grepl("^nodes differ:", diff_nodes)))

  cg_edges_more <- caugi(A %-->% B, B %-->% C, class = "DAG")
  diff_n_edges <- eq_fun(cg_simple, cg_edges_more)
  expect_true(any(grepl("^edges differ:", diff_n_edges)))

  target <- caugi(
    from = c("A", "B"),
    edge = c("-->", "-->"),
    to = c("B", "C"),
    nodes = c("A", "B", "C"),
    class = "DAG"
  )
  current <- caugi(
    from = c("A", "C"),
    edge = c("-->", "-->"),
    to = c("B", "A"),
    nodes = c("A", "B", "C"),
    class = "DAG"
  )
  diff_content <- eq_fun(target, current)
  expect_true(any(grepl(
    "edges have different content",
    diff_content,
    fixed = TRUE
  )))
  expect_type(diff_content, "character")
})
