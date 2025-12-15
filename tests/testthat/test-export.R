# Export Base Class Tests -----------------------------------------------------

test_that("caugi_export has correct structure", {
  # Test through subclass
  cg <- caugi(A %-->% B)
  dot <- to_dot(cg)

  # Check properties exist and have correct types
  expect_type(dot@content, "character")
  expect_type(dot@format, "character")
  expect_equal(dot@format, "dot")

  # Test mermaid too
  mmd <- to_mermaid(cg)
  expect_type(mmd@content, "character")
  expect_type(mmd@format, "character")
  expect_equal(mmd@format, "mermaid")
})

test_that("print method works for all export formats", {
  cg <- caugi(A %-->% B)

  # Test DOT
  dot <- to_dot(cg)
  expect_output(print(dot), "digraph")

  # Test Mermaid
  mmd <- to_mermaid(cg)
  expect_output(print(mmd), "flowchart")
})

test_that("as.character method works for all export formats", {
  cg <- caugi(A %-->% B)

  # Test DOT
  dot <- to_dot(cg)
  dot_str <- as.character(dot)
  expect_type(dot_str, "character")
  expect_equal(dot_str, dot@content)

  # Test Mermaid
  mmd <- to_mermaid(cg)
  mmd_str <- as.character(mmd)
  expect_type(mmd_str, "character")
  expect_equal(mmd_str, mmd@content)
})

test_that("knit_print works for all export formats", {
  skip_if_not_installed("knitr")

  cg <- caugi(A %-->% B)

  # Test DOT
  dot <- to_dot(cg)
  dot_knit <- knitr::knit_print(dot)
  expect_s3_class(dot_knit, "knit_asis")
  expect_match(as.character(dot_knit), "```\\{dot\\}")

  # Test Mermaid
  mmd <- to_mermaid(cg)
  mmd_knit <- knitr::knit_print(mmd)
  expect_s3_class(mmd_knit, "knit_asis")
  expect_match(as.character(mmd_knit), "```\\{mermaid\\}")
})
