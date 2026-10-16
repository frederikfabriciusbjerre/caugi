# Differential test of AG m-separation against an independent oracle.
#
# `fixtures/pag-ground-truth-n4.rds` holds every MAG on four nodes in `amat.pag`
# encoding (`$mags`) together with the m-separation verdict for 24 fixed queries
# (`$queries`) as computed by `ggm::msep` (`$msep`). The expected values are
# stored in the fixture, so `ggm` is not needed at test time.

# `amat.pag` encoding: `A[i, j]` is the mark at node `j` on the edge `{i, j}`.
# 0 = no edge, 2 = arrowhead, 3 = tail (MAGs contain no circles).
.amat_pag_to_ag <- function(A, nms) {
  n <- nrow(A)
  from <- character(0)
  to <- character(0)
  edge <- character(0)

  for (i in seq_len(n - 1L)) {
    for (j in (i + 1L):n) {
      at_j <- A[i, j]
      at_i <- A[j, i]
      if (at_j == 0L && at_i == 0L) {
        next
      }
      if (at_j == 2L && at_i == 3L) {
        from <- c(from, nms[i])
        to <- c(to, nms[j])
        edge <- c(edge, "-->")
      } else if (at_j == 3L && at_i == 2L) {
        from <- c(from, nms[j])
        to <- c(to, nms[i])
        edge <- c(edge, "-->")
      } else if (at_j == 2L && at_i == 2L) {
        from <- c(from, nms[i])
        to <- c(to, nms[j])
        edge <- c(edge, "<->")
      } else if (at_j == 3L && at_i == 3L) {
        from <- c(from, nms[i])
        to <- c(to, nms[j])
        edge <- c(edge, "---")
      } else {
        stop("Unsupported amat.pag marks: ", at_i, " .. ", at_j, call. = FALSE)
      }
    }
  }

  caugi(from = from, edge = edge, to = to, nodes = nms, class = "AG")
}

test_that("m_separated matches the ggm oracle on all 4-node MAGs", {
  skip_on_cran()

  gt <- readRDS(testthat::test_path("fixtures", "pag-ground-truth-n4.rds"))
  nms <- paste0("N", seq_len(gt$n))
  queries <- gt$queries

  mismatches <- character(0)

  for (r in seq_along(gt$mags)) {
    ag <- .amat_pag_to_ag(gt$mags[[r]], nms)

    for (k in seq_along(queries)) {
      q <- queries[[k]]
      expected <- gt$msep[r, k]
      actual <- m_separated(
        ag,
        X = nms[q$i],
        Y = nms[q$j],
        Z = if (length(q$S)) nms[q$S] else NULL
      )

      if (!isTRUE(actual == expected)) {
        mismatches <- c(
          mismatches,
          sprintf(
            "mag %d, query %d: msep(%s, %s | {%s}) expected %s, got %s",
            r,
            k,
            nms[q$i],
            nms[q$j],
            paste(nms[q$S], collapse = ", "),
            expected,
            actual
          )
        )
      }
    }
  }

  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      length(gt$mags) * length(queries),
      " m-separation queries disagree with the oracle. First mismatches:\n",
      paste(utils::head(mismatches, 5L), collapse = "\n")
    )
  )
})
