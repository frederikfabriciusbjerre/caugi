test_that("m_separated on every 4-node PAG matches its class", {
  skip_on_cran()
  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  bad <- character(0)
  for (k in seq_along(gt$pags)) {
    pag <- .amat_pag_to_caugi(gt$pags[[k]], nms, class = "PAG")
    got <- vapply(
      gt$queries,
      function(q) {
        m_separated(pag, nms[q$i], nms[q$j], if (length(q$S)) nms[q$S])
      },
      logical(1)
    )
    if (!identical(got, gt$msep[gt$classes[[k]][1], ])) {
      bad <- c(bad, sprintf("PAG %d", k))
    }
  }
  expect_identical(head(bad, 10L), character(0))
})

test_that("minimal_separator() on a PAG returns a minimal m-separator", {
  pag <- caugi(A %o->% B, C %o->% B, B %-->% D, class = "PAG")
  z <- minimal_separator(pag, "A", "D")
  expect_identical(z, "B")
  expect_true(m_separated(pag, "A", "D", z))
  expect_false(m_separated(pag, "A", "D"))
  expect_null(minimal_separator(pag, "A", "B"))
})
