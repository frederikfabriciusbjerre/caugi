# `pag_to_mag()` against the ground truth, which holds every valid
# four-node PAG together with the m-separation signature of its class.

test_that("pag_to_mag returns a MAG in the represented class, for every 4-node PAG", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  bad <- character(0)

  for (k in seq_along(gt$pags)) {
    P <- gt$pags[[k]]
    storage.mode(P) <- "integer"
    dimnames(P) <- list(nms, nms)
    pag <- .amat_pag_to_caugi(P, nms, class = "PAG")
    mag <- pag_to_mag(pag)
    M <- as_adjacency(mag, coding = "marks")
    definite <- P %in% 2:3

    ok <- identical(mag@graph_class, "AG") &&
      is_mag(mag) &&
      # Same skeleton, and every definite mark kept; only circles resolve.
      identical(M != 0L, P != 0L) &&
      all(M[definite] == P[definite]) &&
      # The right class: its m-separations are the class's.
      all(
        vapply(
          gt$queries,
          function(q) {
            m_separated(mag, nms[q$i], nms[q$j], if (length(q$S)) nms[q$S])
          },
          logical(1)
        ) ==
          gt$msep[gt$classes[[k]][1], ]
      ) &&
      # And back again.
      identical(as_adjacency(mag_to_pag(mag), coding = "marks"), P)
    if (!ok) {
      bad <- c(bad, sprintf("PAG %d", k))
    }
  }
  expect_identical(head(bad, 10L), character(0))
})

test_that("pag_to_mag picks one member and rejects non-PAG input", {
  # `A o-> B <-o C` has both `A --> B <-- C` and `A <-> B <-> C` as members;
  # the construction turns a circle opposite an arrowhead into a tail.
  mag <- pag_to_mag(caugi(A %o->% B, C %o->% B, class = "PAG"))
  expect_true(all(edges(mag)$edge == "-->"))

  expect_error(
    pag_to_mag(caugi(A %-->% B, class = "DAG")),
    "class 'PAG'"
  )
})
