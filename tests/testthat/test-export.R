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

test_that("write_dot() and write_mermaid() write UTF-8 in any locale (#417)", {
  old <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  latin1 <- c("en_US.ISO8859-1", "en_US.iso88591", "English_United States.1252")
  set <- vapply(
    latin1,
    function(l) suppressWarnings(Sys.setlocale("LC_CTYPE", l)) != "",
    TRUE
  )
  skip_if_not(any(set), "No Latin-1 locale available")

  name <- "\u65e5\u672c"
  cg <- caugi(from = "A", edge = "-->", to = name, class = "DAG")
  for (write in list(write_dot, write_mermaid)) {
    f <- tempfile()
    write(cg, f)
    txt <- readLines(f, encoding = "UTF-8", warn = FALSE)
    expect_true(any(grepl(name, txt, fixed = TRUE, useBytes = TRUE)))
  }
})
