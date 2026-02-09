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
