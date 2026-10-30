# Differential test of AG m-separation against an independent oracle.
#
# `fixtures/pag-ground-truth-n4.rds` holds every MAG on four nodes in `amat.pag`
# encoding (`$mags`) together with the m-separation verdict for 24 fixed queries
# (`$queries`) as computed by `ggm::msep` (`$msep`). The expected values are
# stored in the fixture, so `ggm` is not needed at test time.

# MAGs contain no circles, so `.amat_pag_to_caugi()` sees only the codes
# 0 = no edge, 2 = arrowhead and 3 = tail.

test_that("m_separated matches the ggm oracle on all 4-node MAGs", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  queries <- gt$queries

  mismatches <- character(0)

  for (r in seq_along(gt$mags)) {
    ag <- .amat_pag_to_caugi(gt$mags[[r]], nms, class = "AG")

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
