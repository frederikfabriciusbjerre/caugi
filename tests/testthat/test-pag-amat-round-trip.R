# Mark-coded matrix export and import must round-trip.
#
# `as_adjacency(cg, "marks")` writes the `amat.pag` coding that
# `as_caugi(M, class = "PAG")` reads, so every valid PAG must survive a trip
# through the matrix unchanged. The ground-truth fixture supplies all 251
# four-node PAGs, and its matrices are themselves in that coding, which pins
# the convention from both ends.

test_that("every 4-node PAG round-trips through the mark-coded matrix", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  mismatches <- character(0)

  for (k in seq_along(gt$pags)) {
    pag <- .amat_pag_to_caugi(gt$pags[[k]], nms, class = "PAG")

    written <- as_adjacency(pag, coding = "marks")

    # The exporter must reproduce the fixture's own matrix, which is what
    # pins the convention: the code is the mark at the column node.
    expected <- matrix(
      as.integer(gt$pags[[k]]),
      gt$n,
      gt$n,
      dimnames = list(nms, nms)
    )
    if (!identical(written, expected)) {
      mismatches <- c(mismatches, sprintf("PAG %d: exported matrix differs", k))
      next
    }

    back <- as_caugi(written, class = "PAG")
    if (!isTRUE(back == pag)) {
      mismatches <- c(
        mismatches,
        sprintf("PAG %d: re-imported graph differs", k)
      )
    }
  }

  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      length(gt$pags),
      " PAGs failed the matrix round trip. First:\n",
      paste(utils::head(mismatches, 10L), collapse = "\n")
    )
  )
})

test_that("the mark coding rejects glyphs it cannot represent", {
  # A registered edge outside the six PAG types has no mark-coded form.
  reset_caugi_registry()
  on.exit(reset_caugi_registry(), add = TRUE)
  register_caugi_edge("x-x", "other", "other", "undirected", symmetric = TRUE)
  cg <- caugi(A %x-x% B, class = "UNKNOWN")
  expect_error(as_adjacency(cg, coding = "marks"), "Unsupported edge glyphs")
})

test_that("every 4-node PAG round-trips through the caugi file format", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  dir <- file.path(tempdir(), "pag-file-round-trip")
  dir.create(dir, showWarnings = FALSE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  mismatches <- character(0)

  for (k in seq_along(gt$pags)) {
    pag <- .amat_pag_to_caugi(gt$pags[[k]], nms, class = "PAG")
    path <- file.path(dir, sprintf("pag-%03d.caugi.json", k))
    write_caugi(pag, path)
    back <- read_caugi(path)
    if (!isTRUE(back == pag)) {
      mismatches <- c(
        mismatches,
        sprintf("PAG %d differs after a file round trip", k)
      )
    }
  }

  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      length(gt$pags),
      " PAGs failed the file round trip. First:\n",
      paste(utils::head(mismatches, 5L), collapse = "\n")
    )
  )
})
