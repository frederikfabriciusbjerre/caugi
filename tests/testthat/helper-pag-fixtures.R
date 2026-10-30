# Helpers for the PAG ground-truth fixture.
#
# `fixtures/pag-ground-truth-n4.rds` is built offline by
# `tools/pag-ground-truth/generate.R` and holds, for n = 4:
#   $mags     every MAG, in `amat.pag` encoding
#   $msep     n_mags x n_queries logical, from `ggm::msep`
#   $queries  the (i, j, S) behind each column of $msep
#   $classes  Markov equivalence classes, as indices into $mags
#   $pags     the PAG of each class, in the same order as $classes
#
# The decoder below is deliberately local rather than a call to `as_caugi()`:
# these tests check caugi against an external oracle, so they must not depend
# on caugi's own matrix decoding being correct.

# `amat.pag` encoding: `A[i, j]` is the mark at node `j` on the edge `{i, j}`.
# 0 = no edge, 1 = circle, 2 = arrowhead, 3 = tail.
.amat_pag_glyph <- function(at_i, at_j) {
  key <- paste0(at_i, at_j)
  switch(
    key,
    "32" = list(edge = "-->", flip = FALSE), # tail at i, arrow at j
    "23" = list(edge = "-->", flip = TRUE), # arrow at i, tail at j
    "22" = list(edge = "<->", flip = FALSE),
    "33" = list(edge = "---", flip = FALSE),
    "12" = list(edge = "o->", flip = FALSE), # circle at i, arrow at j
    "21" = list(edge = "o->", flip = TRUE),
    "31" = list(edge = "--o", flip = FALSE), # tail at i, circle at j
    "13" = list(edge = "--o", flip = TRUE),
    "11" = list(edge = "o-o", flip = FALSE),
    stop("unsupported endpoint marks: ", at_i, " .. ", at_j, call. = FALSE)
  )
}

.amat_pag_to_caugi <- function(A, nms, class) {
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
      g <- .amat_pag_glyph(at_i, at_j)
      from <- c(from, if (g$flip) nms[j] else nms[i])
      to <- c(to, if (g$flip) nms[i] else nms[j])
      edge <- c(edge, g$edge)
    }
  }

  caugi(from = from, edge = edge, to = to, nodes = nms, class = class)
}

.pag_ground_truth <- function() {
  readRDS(testthat::test_path("fixtures", "pag-ground-truth-n4.rds"))
}
