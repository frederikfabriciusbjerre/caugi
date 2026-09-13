# `pag_to_mag()` must return a MAG from the right Markov equivalence class.
#
# The ground-truth fixture holds every valid PAG on four nodes together with
# the m-separation signature shared by its class, so all four properties below
# are checkable without an external oracle.

test_that("pag_to_mag returns a MAG in the represented class, for every 4-node PAG", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  queries <- gt$queries

  failures <- character(0)
  note <- function(...) failures <<- c(failures, sprintf(...))

  skeleton_of <- function(cg) {
    e <- as.data.frame(edges(cg))
    if (nrow(e) == 0L) {
      return(character(0))
    }
    sort(paste(pmin(e$from, e$to), pmax(e$from, e$to)))
  }

  for (k in seq_along(gt$pags)) {
    pag <- .amat_pag_to_caugi(gt$pags[[k]], nms, class = "PAG")

    mag <- tryCatch(pag_to_mag(pag), error = function(cnd) cnd)
    if (inherits(mag, "condition")) {
      note("PAG %d: pag_to_mag failed: %s", k, conditionMessage(mag))
      next
    }

    # 1. it is a MAG
    if (!identical(mag@graph_class, "AG")) {
      note("PAG %d: class is %s, not AG", k, mag@graph_class)
    }
    if (!is_mag(mag)) {
      note("PAG %d: result is not maximal", k)
    }

    # 2. Markov equivalent MAGs share a skeleton, and a PAG has its class's
    #    skeleton, so the two must agree.
    if (!identical(skeleton_of(mag), skeleton_of(pag))) {
      note("PAG %d: skeleton changed", k)
    }

    # 3. every definite mark in the PAG survives; only circles may resolve
    for (i in seq_len(gt$n)) {
      for (j in seq_len(gt$n)) {
        if (i == j) {
          next
        }
        # `A[i, j]` is the mark at `j` on the edge `{i, j}`. The fixture
        # matrices are stored as doubles, so coerce before comparing.
        before <- as.integer(gt$pags[[k]][i, j])
        if (before %in% c(2L, 3L)) {
          after <- .mark_at(mag, nms[j], nms[i])
          if (!identical(after, before)) {
            note(
              "PAG %d: definite mark at %s on edge to %s changed %d -> %s",
              k,
              nms[j],
              nms[i],
              before,
              format(after)
            )
          }
        }
      }
    }

    # 4. the strongest property: the MAG is in the *right* class, i.e. it
    #    reproduces that class's m-separation signature exactly.
    expected <- gt$msep[gt$classes[[k]][1], ]
    for (q in seq_along(queries)) {
      qq <- queries[[q]]
      actual <- m_separated(
        mag,
        X = nms[qq$i],
        Y = nms[qq$j],
        Z = if (length(qq$S)) nms[qq$S] else NULL
      )
      if (!isTRUE(actual == expected[q])) {
        note(
          "PAG %d: constructed MAG disagrees on msep(%s, %s | {%s})",
          k,
          nms[qq$i],
          nms[qq$j],
          paste(nms[qq$S], collapse = ", ")
        )
      }
    }
  }

  expect_equal(
    length(failures),
    0L,
    info = paste0(
      length(failures),
      " failures across ",
      length(gt$pags),
      " PAGs. First:\n",
      paste(utils::head(failures, 10L), collapse = "\n")
    )
  )
})

test_that("pag_to_mag rejects non-PAG input", {
  expect_error(
    pag_to_mag(caugi(A %-->% B, class = "DAG")),
    "class 'PAG'"
  )
})
