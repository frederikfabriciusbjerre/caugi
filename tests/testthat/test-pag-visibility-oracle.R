# Edge visibility in a PAG, checked against pcalg::visibleEdge.
#
# `pcalg::visibleEdge(amat, x, z)` is an independent implementation of the same
# criterion (Zhang 2008, Def. 8) over the same `amat.pag` encoding the fixture
# uses, and it decomposes the same way: a scan for an arrowhead at `x` from a
# node disconnected from `z`, then a discriminating-path search
# (`pcalg:::minDiscrPath`) seeded at each spouse of `x` that is a parent of `z`.
#
# Every directed edge of every fixture PAG is compared, in the direction the
# edge points. `visibleEdge()` does not itself check that the edge is `-->`, so
# it must not be called on any other edge type.
#
# The comparison is restricted to selection-free PAGs, as elsewhere in these
# oracle tests: `pcalg`'s PAG functions assume no selection variables and
# `dsepAM()` and `possDe()` are both wrong on `---`. `visibleEdge()` itself
# reads endpoint marks directly and never consults m-separation, so it has no
# reason to share that defect -- and on the three fixture PAGs that do contain
# `---` it agrees with caugi. It is skipped here anyway, to keep the oracle
# boundary in one place rather than argued case by case.

test_that("is_visible_edge matches pcalg::visibleEdge on all 4-node PAGs", {
  skip_on_cran()
  skip_if_not_installed("pcalg")

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  mismatches <- character(0)
  compared <- 0L

  # `---` is mark 3 at both ends; see the note above.
  has_undirected <- function(A) {
    any(A == 3L & t(A) == 3L)
  }

  for (k in seq_along(gt$pags)) {
    A <- gt$pags[[k]]
    if (has_undirected(A)) {
      next
    }
    dimnames(A) <- list(nms, nms)
    pag <- .amat_pag_to_caugi(A, nms, class = "PAG")

    # `amat.pag` codes the mark at the column node, so `A[i, j] == 2` and
    # `A[j, i] == 3` is the directed edge `i --> j`.
    for (i in seq_len(gt$n)) {
      for (j in seq_len(gt$n)) {
        if (i == j || A[i, j] != 2L || A[j, i] != 3L) {
          next
        }
        expected <- pcalg::visibleEdge(A, i, j)
        actual <- is_visible_edge(pag, nms[i], nms[j])
        compared <- compared + 1L
        if (!identical(expected, actual)) {
          mismatches <- c(
            mismatches,
            sprintf(
              "PAG %d, %s --> %s: pcalg %s, caugi %s",
              k,
              nms[i],
              nms[j],
              expected,
              actual
            )
          )
        }
      }
    }
  }

  expect_gt(compared, 0L)
  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      compared,
      " visibility queries disagree with pcalg. First mismatches:\n",
      paste(utils::head(mismatches, 10L), collapse = "\n")
    )
  )
})

test_that("only directed edges are visible", {
  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))

  # `visibleEdge()` cannot check this: it assumes the edge it is given is
  # directed. Every non-directed ordered pair must come back `FALSE`, which
  # covers `o->`, `<->`, `---`, `--o`, `o-o`, non-adjacency and the reverse of
  # a directed edge in one sweep.
  bad <- character(0)
  for (k in seq_along(gt$pags)) {
    A <- gt$pags[[k]]
    pag <- .amat_pag_to_caugi(A, nms, class = "PAG")
    for (i in seq_len(gt$n)) {
      for (j in seq_len(gt$n)) {
        if (i == j) {
          next
        }
        directed <- A[i, j] == 2L && A[j, i] == 3L
        if (!directed && is_visible_edge(pag, nms[i], nms[j])) {
          bad <- c(bad, sprintf("PAG %d: %s .. %s", k, nms[i], nms[j]))
        }
      }
    }
  }

  expect_equal(
    length(bad),
    0L,
    info = paste0(
      "non-directed pairs reported visible:\n",
      paste(utils::head(bad, 10L), collapse = "\n")
    )
  )
})
