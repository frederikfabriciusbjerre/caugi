test_that("caugi_serialize produces valid JSON", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    class = "DAG"
  )

  json <- caugi_serialize(cg)
  expect_type(json, "character")
  expect_true(nchar(json) > 0)

  # Should be valid JSON
  parsed <- jsonlite::fromJSON(json)
  expect_equal(parsed$format, "caugi")
  expect_equal(parsed$version, "1.0.0")
  expect_equal(parsed$graph$class, "DAG")
})

test_that("write_caugi and read_caugi round-trip correctly", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))

  write_caugi(cg, tmp)
  expect_true(file.exists(tmp))

  cg2 <- read_caugi(tmp)
  expect_true(is_caugi(cg2))
  expect_equal(cg@graph_class, cg2@graph_class)
  expect_setequal(cg@nodes$name, cg2@nodes$name)
  expect_equal(nrow(edges(cg)), nrow(edges(cg2)))
})

test_that("serialization preserves different graph classes", {
  graphs <- list(
    caugi(A %-->% B, class = "DAG"),
    caugi(A %---% B, class = "UG"),
    caugi(A %-->% B, B %---% C, class = "PDAG"),
    caugi(A %<->% B, class = "ADMG")
  )

  for (cg in graphs) {
    json <- caugi_serialize(cg)
    parsed <- jsonlite::fromJSON(json)
    expect_equal(parsed$graph$class, cg@graph_class)
  }
})

test_that("serialization preserves edge types", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %o->% E,
    class = "UNKNOWN"
  )

  json <- caugi_serialize(cg)
  parsed <- jsonlite::fromJSON(json)

  expect_setequal(
    parsed$graph$edges$edge,
    c("-->", "---", "<->", "o->")
  )
})

test_that("serialization handles isolated nodes", {
  cg <- caugi(
    A %-->% B,
    nodes = c("A", "B", "C", "D"),
    class = "DAG"
  )

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))

  write_caugi(cg, tmp)
  cg2 <- read_caugi(tmp)

  expect_equal(nrow(cg@nodes), nrow(cg2@nodes))
  expect_setequal(cg@nodes$name, cg2@nodes$name)
})

test_that("serialization handles empty graphs", {
  cg <- caugi(nodes = c("A", "B", "C"), class = "DAG")

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))

  write_caugi(cg, tmp)
  cg2 <- read_caugi(tmp)

  expect_equal(nrow(cg@nodes), nrow(cg2@nodes))
  expect_equal(nrow(edges(cg)), 0)
  expect_equal(nrow(edges(cg2)), 0)
})

test_that("serialization with comments and tags", {
  cg <- caugi(A %-->% B, class = "DAG")

  json <- caugi_serialize(
    cg,
    comment = "Test graph",
    tags = c("test", "example")
  )
  parsed <- jsonlite::fromJSON(json)

  expect_equal(parsed$meta$comment, "Test graph")
  expect_equal(parsed$meta$tags, c("test", "example"))
})

test_that("write_caugi with comments and tags", {
  cg <- caugi(A %-->% B, class = "DAG")

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))

  write_caugi(cg, tmp, comment = "Test", tags = "experiment")
  json_content <- readLines(tmp, warn = FALSE)
  json_str <- paste(json_content, collapse = "\n")
  parsed <- jsonlite::fromJSON(json_str)

  expect_equal(parsed$meta$comment, "Test")
  expect_equal(parsed$meta$tags, "experiment")
})

test_that("read_caugi creates graph with session", {
  cg <- caugi(A %-->% B + C, class = "DAG")

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))

  write_caugi(cg, tmp)
  cg2 <- read_caugi(tmp)

  expect_true(!is.null(cg2@session))
})

test_that("deserialization validates edge types", {
  # Create a valid caugi file
  cg <- caugi(A %-->% B, class = "DAG")
  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))
  write_caugi(cg, tmp)

  # Manually corrupt the edge type
  json_content <- readLines(tmp, warn = FALSE)
  json_str <- paste(json_content, collapse = "\n")
  json_str <- gsub('"-->"', '"invalid_edge"', json_str)
  writeLines(json_str, tmp)

  expect_error(read_caugi(tmp), "Unknown edge type")
})

test_that("deserialization validates node references", {
  # Manually create invalid JSON
  invalid_json <- '{
    "format": "caugi",
    "version": "1.0.0",
    "graph": {
      "class": "DAG",
      "nodes": ["A", "B"],
      "edges": [
        {"from": "A", "to": "C", "edge": "-->"}
      ]
    }
  }'

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))
  writeLines(invalid_json, tmp)

  expect_error(read_caugi(tmp), "Unknown node")
})

test_that("serialization preserves node order", {
  cg <- caugi(
    from = c("Z", "Y", "X"),
    edge = c("-->", "-->", "-->"),
    to = c("Y", "X", "W"),
    nodes = c("Z", "Y", "X", "W"),
    class = "DAG"
  )

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))

  write_caugi(cg, tmp)
  cg2 <- read_caugi(tmp)

  expect_equal(cg@nodes$name, cg2@nodes$name)
})

test_that("caugi_deserialize works with string input", {
  cg <- caugi(A %-->% B, class = "DAG")
  json <- caugi_serialize(cg)

  cg2 <- caugi_deserialize(json)
  expect_true(is_caugi(cg2))
  expect_equal(cg@graph_class, cg2@graph_class)
})

test_that("semantic versioning - minor/patch versions are compatible", {
  # Version 1.0.0 (current)
  cg <- caugi(A %-->% B, class = "DAG")
  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))
  write_caugi(cg, tmp)

  json <- readLines(tmp)

  # Test version 1.1.0 (minor bump - should be compatible)
  json_v110 <- gsub('"version": "1.0.0"', '"version": "1.1.0"', json)
  writeLines(json_v110, tmp)
  cg2 <- read_caugi(tmp)
  expect_true(is_caugi(cg2))

  # Test version 1.0.1 (patch bump - should be compatible)
  json_v101 <- gsub('"version": "1.0.0"', '"version": "1.0.1"', json)
  writeLines(json_v101, tmp)
  cg3 <- read_caugi(tmp)
  expect_true(is_caugi(cg3))
})

test_that("semantic versioning - major version mismatch is rejected", {
  cg <- caugi(A %-->% B, class = "DAG")
  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))
  write_caugi(cg, tmp)

  # Change to version 2.0.0
  json <- readLines(tmp)
  json_v2 <- gsub('"version": "1.0.0"', '"version": "2.0.0"', json)
  writeLines(json_v2, tmp)

  expect_error(read_caugi(tmp), "Incompatible format version")
})

test_that("read_caugi validates inputs", {
  expect_error(read_caugi(123), "`path` must be a single character string")
  expect_error(
    read_caugi(c("a", "b")),
    "`path` must be a single character string"
  )
  expect_error(read_caugi("nonexistent.json"), "File not found")

  tmp <- tempfile(fileext = ".caugi.json")
  on.exit(unlink(tmp))
  write_caugi(caugi(A %-->% B, class = "DAG"), tmp)
})

test_that("caugi_serialize validates inputs", {
  cg <- caugi(A %-->% B, class = "DAG")

  expect_error(
    caugi_serialize(cg, comment = 123),
    "`comment` must be NULL or a single character string"
  )
  expect_error(
    caugi_serialize(cg, comment = c("a", "b")),
    "`comment` must be NULL or a single character string"
  )
  expect_error(
    caugi_serialize(cg, tags = 123),
    "`tags` must be NULL or a character vector"
  )
})

test_that("caugi_deserialize validates inputs", {
  expect_error(
    caugi_deserialize(123),
    "`json` must be a single character string"
  )
  expect_error(
    caugi_deserialize(c("a", "b")),
    "`json` must be a single character string"
  )
})

test_that("caugi_deserialize handles empty graphs", {
  cg <- caugi(nodes = c("A", "B"), class = "DAG")
  json <- caugi_serialize(cg)

  cg2 <- caugi_deserialize(json)

  expect_true(is_caugi(cg2))
  expect_true(!is.null(cg2@session))
  expect_equal(nrow(cg2@nodes), 2)
})

test_that("write_caugi validates inputs", {
  cg <- caugi(A %-->% B, class = "DAG")

  expect_error(write_caugi(cg, 123), "`path` must be a single character string")
  expect_error(
    write_caugi(cg, c("a.json", "b.json")),
    "`path` must be a single character string"
  )
  expect_error(
    write_caugi(cg, "test.json", comment = 123),
    "`comment` must be NULL or a single character string"
  )
  expect_error(
    write_caugi(cg, "test.json", comment = c("a", "b")),
    "`comment` must be NULL or a single character string"
  )
  expect_error(
    write_caugi(cg, "test.json", tags = 123),
    "`tags` must be NULL or a character vector"
  )
})
