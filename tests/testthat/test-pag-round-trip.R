# The PAG -> MAG -> PAG round trip.
#
# `mag_to_pag(pag_to_mag(P))` returns `P` exactly when `P`'s marks are the
# invariant marks of a Markov equivalence class. That is the property that
# decides PAG validity. This file covers the positive direction over all 251
# valid four-node PAGs, and asserts the marks come back *identical* rather than
# merely that the graph is accepted, which is the more useful diagnostic when
# a rule misfires.
#
# The negative direction -- graphs that are structurally plausible but not
# valid -- is covered by `test-pag-is-pag-exhaustive.R`, which sweeps every
# single-edge mutant through the public `is_pag()`.

# The `amat.pag` matrix of a caugi PAG, for comparing two graphs mark by mark.
.pag_amat <- function(cg, nms) {
  n <- length(nms)
  A <- matrix(0L, n, n, dimnames = list(nms, nms))
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i != j) {
        A[i, j] <- .mark_at(cg, nms[j], nms[i])
      }
    }
  }
  A
}

test_that("every valid 4-node PAG survives the MAG round trip", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  failures <- character(0)

  for (k in seq_along(gt$pags)) {
    pag <- .amat_pag_to_caugi(gt$pags[[k]], nms, class = "PAG")
    back <- tryCatch(mag_to_pag(pag_to_mag(pag)), error = function(cnd) cnd)
    if (inherits(back, "condition")) {
      failures <- c(
        failures,
        sprintf("PAG %d: round trip errored: %s", k, conditionMessage(back))
      )
      next
    }
    before <- matrix(
      as.integer(gt$pags[[k]]),
      gt$n,
      gt$n,
      dimnames = list(nms, nms)
    )
    after <- .pag_amat(back, nms)
    if (!identical(before, after)) {
      failures <- c(failures, sprintf("PAG %d: marks changed", k))
    }
  }

  expect_equal(
    length(failures),
    0L,
    info = paste0(
      length(failures),
      " of ",
      length(gt$pags),
      " PAGs did not survive the round trip. First:\n",
      paste(utils::head(failures, 10L), collapse = "\n")
    )
  )
})
