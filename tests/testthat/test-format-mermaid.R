test_that("to_mermaid works with simple DAG", {
  cg <- caugi(
    A %-->% B + C,
    B %-->% D,
    C %-->% D,
    class = "DAG"
  )

  mmd <- to_mermaid(cg)

  expect_s7_class(mmd, caugi_mermaid)
  expect_equal(mmd@format, "mermaid")
  mmd_str <- as.character(mmd)
  expect_match(mmd_str, "flowchart TD")
  expect_match(mmd_str, "A --> B")
  expect_match(mmd_str, "A --> C")
  expect_match(mmd_str, "B --> D")
  expect_match(mmd_str, "C --> D")
})

test_that("to_mermaid handles different edge types", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    D %o->% E
  )

  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)

  expect_match(mmd_str, "A --> B")
  expect_match(mmd_str, "B --- C")
  expect_match(mmd_str, "C <--> D")
  expect_match(mmd_str, "D o--> E")
})

test_that("to_mermaid accepts direction argument", {
  cg <- caugi(A %-->% B, class = "DAG")

  # Test all valid directions
  mmd_td <- to_mermaid(cg, direction = "TD")
  expect_match(as.character(mmd_td), "flowchart TD")

  mmd_tb <- to_mermaid(cg, direction = "TB")
  expect_match(as.character(mmd_tb), "flowchart TB")

  mmd_lr <- to_mermaid(cg, direction = "LR")
  expect_match(as.character(mmd_lr), "flowchart LR")

  mmd_rl <- to_mermaid(cg, direction = "RL")
  expect_match(as.character(mmd_rl), "flowchart RL")

  mmd_bt <- to_mermaid(cg, direction = "BT")
  expect_match(as.character(mmd_bt), "flowchart BT")
})

test_that("to_mermaid validates direction", {
  cg <- caugi(A %-->% B, class = "DAG")

  expect_error(
    to_mermaid(cg, direction = "INVALID"),
    "Invalid direction"
  )
})

test_that("to_mermaid escapes special characters", {
  cg <- caugi(
    "Node 1" %-->% "Node-2",
    "Node-2" %-->% "Node_3"
  )

  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)

  expect_match(mmd_str, '"Node 1"')
  expect_match(mmd_str, '"Node-2"')
  expect_match(mmd_str, "Node_3") # No quotes needed for valid identifier
})

test_that("to_mermaid works with single node", {
  cg <- caugi(A, class = "DAG")

  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)

  expect_match(mmd_str, "flowchart TD")
  expect_match(mmd_str, "\\s+A\\s*$", perl = TRUE) # Node alone on line
})

test_that("to_mermaid works with empty graph", {
  cg <- caugi(A + B + C, class = "DAG")

  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)

  expect_match(mmd_str, "\\s+A")
  expect_match(mmd_str, "\\s+B")
  expect_match(mmd_str, "\\s+C")
})

test_that("to_mermaid builds graph if needed", {
  cg <- caugi(A %-->% B)

  mmd <- to_mermaid(cg)

  expect_s7_class(mmd, caugi_mermaid)
  expect_match(as.character(mmd), "A --> B")
})

test_that("write_mermaid creates file", {
  cg <- caugi(A %-->% B, class = "DAG")

  tmp <- tempfile(fileext = ".mmd")
  result <- write_mermaid(cg, tmp)

  expect_true(file.exists(tmp))
  expect_equal(result, tmp)

  content <- readLines(tmp)
  expect_match(paste(content, collapse = "\n"), "A --> B")

  unlink(tmp)
})

test_that("write_mermaid accepts direction", {
  cg <- caugi(A %-->% B, class = "DAG")

  tmp <- tempfile(fileext = ".mmd")
  write_mermaid(cg, tmp, direction = "LR")

  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, "flowchart LR")

  unlink(tmp)
})

test_that("to_mermaid handles unsupported edge types", {
  # o-o edges are not explicitly supported by mermaid format
  # Should default to directed edge
  cg <- caugi(
    A %o-o% B,
    class = "UNKNOWN"
  )

  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)

  # Should use default directed arrow for unsupported edge type
  expect_match(mmd_str, "A --> B", fixed = TRUE)
})

test_that("to_mermaid handles --o edge type", {
  # --o edges are not explicitly supported
  # Should default to directed edge
  cg <- caugi(
    A %--o% B,
    class = "UNKNOWN"
  )

  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)

  # Should use default directed arrow for unsupported edge type
  expect_match(mmd_str, "A --> B", fixed = TRUE)
})
