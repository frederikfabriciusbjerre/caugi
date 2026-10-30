# Visibility is checked against pcalg::visibleEdge, an independent
# implementation of the same criterion (Zhang 2008, Def. 8) over the same
# `amat.pag` coding the ground truth uses.
#
# Graphs with `---` are skipped: pcalg's MAG and PAG functions assume no
# selection variables. Every other directed edge is compared, in the direction
# it points; `visibleEdge()` assumes its edge is `-->`, so it is never called
# on anything else. Every other ordered pair must be invisible.
.visibility_mismatches <- function(mats, class) {
  nms <- paste0("N", seq_len(nrow(mats[[1]])))
  bad <- character(0)
  compared <- 0L
  for (k in seq_along(mats)) {
    A <- mats[[k]]
    cg <- .amat_pag_to_caugi(A, nms, class = class)
    directed <- A == 2L & t(A) == 3L # directed[i, j] iff i --> j
    selection <- any(A == 3L & t(A) == 3L)
    for (i in seq_along(nms)) {
      for (j in seq_along(nms)[-i]) {
        if (directed[i, j] && selection) {
          next
        }
        expected <- directed[i, j] && pcalg::visibleEdge(A, i, j)
        actual <- is_visible_edge(cg, nms[i], nms[j])
        compared <- compared + directed[i, j]
        if (!identical(actual, expected)) {
          bad <- c(bad, sprintf("graph %d, %s -> %s", k, nms[i], nms[j]))
        }
      }
    }
  }
  list(bad = bad, compared = compared)
}

test_that("is_visible_edge matches pcalg::visibleEdge on all 4-node MAGs", {
  skip_on_cran()
  skip_if_not_installed("pcalg")
  res <- .visibility_mismatches(.pag_ground_truth()$mags, "AG")
  expect_gt(res$compared, 0L)
  expect_identical(head(res$bad, 10L), character(0))
})

test_that("is_visible_edge matches pcalg::visibleEdge on all 4-node PAGs", {
  skip_on_cran()
  skip_if_not_installed("pcalg")
  res <- .visibility_mismatches(.pag_ground_truth()$pags, "PAG")
  expect_gt(res$compared, 0L)
  expect_identical(head(res$bad, 10L), character(0))
})

test_that("is_visible_edge reads the pcalg example", {
  mag <- caugi(A %-->% B, B %<->% C, B %-->% D, C %-->% D, class = "AG")
  expect_false(is_visible_edge(mag, "A", "B"))
  expect_true(is_visible_edge(mag, "B", "D"))
  expect_true(is_visible_edge(mag, "C", "D"))
  expect_true(is_visible_edge(mag, from_index = 3, to_index = 4))
  expect_false(is_visible_edge(mag, "D", "C"))
})

test_that("visibility needs a witness not adjacent to the head", {
  # The edge in the MAG of A --> L --> B with L latent is visible: C and D
  # rule out a latent confounder of A and B, though not the mediator L.
  dag <- caugi(C %-->% A, D %-->% A, A %-->% L, L %-->% B, class = "DAG")
  mag <- condition_marginalize(dag, marg_vars = "L")
  expect_true(is_visible_edge(mag, "A", "B"))
  expect_false(is_visible_edge(caugi(A %-->% B, class = "AG"), "A", "B"))
})

test_that("is_visible_edge validates its input", {
  mag <- caugi(A %-->% B, class = "AG")
  expect_error(is_visible_edge(mag, c("A", "B"), "B"), "exactly one node")
  expect_error(is_visible_edge(mag, "A"), "exactly one node")
  expect_error(is_visible_edge(mag, from_index = 3, to_index = 1), "Index 3")
  expect_error(
    is_visible_edge(caugi(A %-->% B, class = "DAG"), "A", "B"),
    "only defined for MAGs and PAGs"
  )
  pag <- caugi(A %-->% B, C %o->% A, D %o->% A, C %-->% B, class = "PAG")
  expect_true(is_visible_edge(pag, "A", "B"))
  expect_false(is_visible_edge(pag, "C", "B"))
})
