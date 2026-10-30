# Every MAG and PAG on four nodes, built from the definitions with caugi's
# `is_ag()` and `m_separated()` (checked against ggm in
# test-ag-msep-oracle.R). Graphs are `amat.pag` matrices: `A[i, j]` is the
# mark at `j` on the edge `{i, j}`; 0 none, 1 circle, 2 arrowhead, 3 tail.
#
# `.pag_ground_truth()` returns, built once per test run:
#   $mags     every MAG
#   $queries  every query `list(i, j, S)` with `S` drawn from the other nodes
#   $msep     MAGs x queries: is `i` m-separated from `j` given `S`?
#   $classes  Markov equivalence classes (same m-separations), as $mags indices
#   $pags     each class's PAG: a mark is kept iff every member has it
#   $keys     each PAG as a string, for lookup

# A caugi graph from an `amat.pag` matrix.
.amat_pag_to_caugi <- function(A, nms, class) {
  glyph <- c(
    "32" = "-->",
    "23" = "<--",
    "22" = "<->",
    "33" = "---",
    "12" = "o->",
    "21" = "<-o",
    "31" = "--o",
    "13" = "o--",
    "11" = "o-o"
  )
  ij <- which(upper.tri(A) & A != 0, arr.ind = TRUE)
  g <- unname(glyph[paste0(A[ij[, 2:1, drop = FALSE]], A[ij])])
  flip <- g %in% c("<--", "<-o", "o--")
  g[flip] <- c("<--" = "-->", "<-o" = "o->", "o--" = "--o")[g[flip]]
  from <- nms[ifelse(flip, ij[, 2], ij[, 1])]
  to <- nms[ifelse(flip, ij[, 1], ij[, 2])]
  caugi(from = from, edge = g, to = to, nodes = nms, class = class)
}

.pag_ground_truth <- local({
  gt <- NULL
  function() {
    if (is.null(gt)) {
      gt <<- .pag_build_ground_truth()
    }
    gt
  }
})

.pag_build_ground_truth <- function(n = 4L) {
  nms <- paste0("N", seq_len(n))
  pairs <- utils::combn(n, 2)
  queries <- list()
  for (k in seq_len(ncol(pairs))) {
    rest <- setdiff(seq_len(n), pairs[, k])
    for (s in 0:length(rest)) {
      for (S in utils::combn(rest, s, simplify = FALSE)) {
        queries[[length(queries) + 1L]] <- list(
          i = pairs[1, k],
          j = pairs[2, k],
          S = S
        )
      }
    }
  }
  pair_of <- vapply(queries, function(q) paste(q$i, q$j), "")

  # An edge as (mark at i, mark at j): none, -->, <--, <->, ---.
  states <- list(c(0L, 0L), c(3L, 2L), c(2L, 3L), c(2L, 2L), c(3L, 3L))
  mags <- list()
  rows <- list()
  for (code in seq_len(5^ncol(pairs)) - 1L) {
    A <- matrix(0L, n, n)
    st <- (code %/% 5^(seq_len(ncol(pairs)) - 1L)) %% 5L
    for (k in seq_len(ncol(pairs))) {
      A[pairs[2, k], pairs[1, k]] <- states[[st[k] + 1L]][1]
      A[pairs[1, k], pairs[2, k]] <- states[[st[k] + 1L]][2]
    }
    cg <- .amat_pag_to_caugi(A, nms, class = "UNKNOWN")
    if (!is_ag(cg)) {
      next
    }
    cg <- mutate_caugi(cg, "AG")
    sep <- vapply(
      queries,
      function(q) {
        m_separated(cg, nms[q$i], nms[q$j], if (length(q$S)) nms[q$S])
      },
      TRUE
    )
    # Maximal: a pair is separable iff it is not adjacent.
    separable <- tapply(sep, pair_of, any)[paste(pairs[1, ], pairs[2, ])]
    if (any(separable == (A[t(pairs)] != 0L))) {
      next
    }
    mags[[length(mags) + 1L]] <- A
    rows[[length(rows) + 1L]] <- sep
  }

  msep <- do.call(rbind, rows)
  classes <- unname(split(
    seq_along(mags),
    apply(msep, 1, paste, collapse = "")
  ))
  pags <- lapply(classes, function(cl) {
    marks <- simplify2array(mags[cl])
    P <- marks[,, 1]
    P[apply(marks, 1:2, function(v) any(v != v[1]))] <- 1L
    P
  })
  list(
    n = n,
    mags = mags,
    queries = queries,
    msep = msep,
    classes = classes,
    pags = pags,
    keys = vapply(pags, paste, "", collapse = ",")
  )
}
