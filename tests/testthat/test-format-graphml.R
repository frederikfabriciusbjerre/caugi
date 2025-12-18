test_that("to_graphml produces valid XML structure", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    class = "DAG"
  )

  graphml <- to_graphml(cg)
  expect_true(S7::S7_inherits(graphml, caugi_graphml))
  expect_true(grepl("<?xml", graphml@content, fixed = TRUE))
  expect_true(grepl("<graphml", graphml@content))
  expect_true(grepl("</graphml>", graphml@content))
})

test_that("write_graphml and read_graphml round-trip", {
  skip_if_not_installed("xml2")

  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  tmp <- tempfile(fileext = ".graphml")
  on.exit(unlink(tmp))

  write_graphml(cg, tmp)
  expect_true(file.exists(tmp))

  cg2 <- read_graphml(tmp)
  expect_true(is_caugi(cg2))
  expect_equal(cg@graph_class, cg2@graph_class)
  expect_setequal(cg@nodes$name, cg2@nodes$name)
  expect_equal(nrow(edges(cg)), nrow(edges(cg2)))
})

test_that("GraphML preserves edge types", {
  skip_if_not_installed("xml2")

  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %o->% E,
    class = "UNKNOWN"
  )

  tmp <- tempfile(fileext = ".graphml")
  on.exit(unlink(tmp))

  write_graphml(cg, tmp)
  cg2 <- read_graphml(tmp)

  expect_setequal(
    edges(cg)$edge,
    edges(cg2)$edge
  )
})

test_that("GraphML handles isolated nodes", {
  skip_if_not_installed("xml2")

  cg <- caugi(
    A %-->% B,
    nodes = c("A", "B", "C", "D"),
    class = "DAG"
  )

  tmp <- tempfile(fileext = ".graphml")
  on.exit(unlink(tmp))

  write_graphml(cg, tmp)
  cg2 <- read_graphml(tmp)

  expect_equal(nrow(cg@nodes), nrow(cg2@nodes))
  expect_setequal(cg@nodes$name, cg2@nodes$name)
})

test_that("GraphML handles empty graphs", {
  skip_if_not_installed("xml2")

  cg <- caugi(nodes = c("A", "B", "C"), class = "UG")

  tmp <- tempfile(fileext = ".graphml")
  on.exit(unlink(tmp))

  write_graphml(cg, tmp)
  cg2 <- read_graphml(tmp)

  expect_equal(nrow(cg@nodes), nrow(cg2@nodes))
  expect_equal(nrow(edges(cg)), 0)
  expect_equal(nrow(edges(cg2)), 0)
})

test_that("GraphML escapes XML special characters", {
  skip_if_not_installed("xml2")

  cg <- caugi(
    `A<B` %-->% `C&D`,
    class = "DAG"
  )

  tmp <- tempfile(fileext = ".graphml")
  on.exit(unlink(tmp))

  write_graphml(cg, tmp)
  cg2 <- read_graphml(tmp)

  expect_setequal(cg@nodes$name, cg2@nodes$name)
  expect_true("A<B" %in% cg2@nodes$name)
  expect_true("C&D" %in% cg2@nodes$name)
})

test_that("GraphML handles different graph classes", {
  skip_if_not_installed("xml2")

  graphs <- list(
    caugi(A %-->% B, class = "DAG"),
    caugi(A %---% B, class = "UG"),
    caugi(A %-->% B, B %---% C, class = "PDAG"),
    caugi(A %<->% B, class = "ADMG")
  )

  for (cg in graphs) {
    tmp <- tempfile(fileext = ".graphml")
    on.exit(unlink(tmp), add = TRUE)

    write_graphml(cg, tmp)
    cg2 <- read_graphml(tmp)

    expect_equal(cg@graph_class, cg2@graph_class)
  }
})

test_that("read_graphml can override class", {
  skip_if_not_installed("xml2")

  cg <- caugi(A %-->% B, class = "DAG")

  tmp <- tempfile(fileext = ".graphml")
  on.exit(unlink(tmp))

  write_graphml(cg, tmp)

  # Override class on read
  cg2 <- read_graphml(tmp, class = "UNKNOWN")
  expect_equal(cg2@graph_class, "UNKNOWN")
})
