# `is_pag()` against the complete ground truth for four nodes.
#
# The ground truth holds every valid four-node PAG, so validity is decidable by
# table lookup and `is_pag()` can be checked against it rather than against
# hand-written expectations. Every single-edge mutant of every valid PAG is
# swept, which is where the signal is. Those near-misses are exactly what a
# check of the structural invariants alone would wrongly accept: both
# over-oriented graphs (a definite mark that is not invariant across the class)
# and under-oriented ones (a circle where an invariant mark belongs).
#
# Mutant validity is always looked up, never assumed. At n = 4, 672 of the
# 13,554 single-edge mutants land back on a *valid* PAG, so asserting that
# mutation breaks validity would be wrong 672 times over.

test_that("is_pag agrees with the ground truth on every 4-node PAG and mutant", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  n <- gt$n
  nms <- paste0("N", seq_len(n))

  valid <- new.env(hash = TRUE, parent = emptyenv())
  for (k in gt$keys) {
    assign(k, TRUE, envir = valid)
  }
  is_valid <- function(A) {
    exists(paste(A, collapse = ","), envir = valid, inherits = FALSE)
  }

  # `is_pag()` on a mark matrix, going through the public constructor so the
  # structural stages are exercised too. A matrix the constructor rejects is
  # not a PAG, which is the right answer rather than an error.
  check <- function(A) {
    cg <- tryCatch(
      .amat_pag_to_caugi(A, nms, class = "PAG"),
      error = function(cnd) NULL
    )
    if (is.null(cg)) {
      return(FALSE)
    }
    is_pag(cg)
  }

  mismatches <- character(0)
  tested <- 0L
  n_valid_mutants <- 0L

  note <- function(A, expected, actual, what) {
    mismatches <<- c(
      mismatches,
      sprintf(
        "%s [%s]: expected %s, got %s",
        what,
        paste(A, collapse = ""),
        expected,
        actual
      )
    )
  }

  for (k in seq_along(gt$pags)) {
    P <- matrix(as.integer(gt$pags[[k]]), n, n)

    # The valid PAG itself.
    tested <- tested + 1L
    got <- check(P)
    if (!isTRUE(got)) {
      note(P, TRUE, got, sprintf("valid PAG %d", k))
    }

    # Every single-endpoint mutation of every present edge, plus edge removal
    # and the two ways to add marks to an absent edge.
    for (i in seq_len(n - 1L)) {
      for (j in (i + 1L):n) {
        for (mi in 0:3) {
          for (mj in 0:3) {
            if ((mi == 0L) != (mj == 0L)) {
              next # an edge has marks at both ends or neither
            }
            Q <- P
            Q[j, i] <- as.integer(mi)
            Q[i, j] <- as.integer(mj)
            if (identical(Q, P)) {
              next
            }
            expected <- is_valid(Q)
            if (expected) {
              n_valid_mutants <- n_valid_mutants + 1L
            }
            tested <- tested + 1L
            got <- check(Q)
            if (!identical(got, expected)) {
              note(Q, expected, got, sprintf("mutant of PAG %d", k))
            }
          }
        }
      }
    }
  }

  # Guards against a vacuous pass: both answers must actually occur.
  expect_gt(tested, 10000L)
  expect_gt(n_valid_mutants, 0L)
  expect_equal(
    length(mismatches),
    0L,
    info = paste0(
      length(mismatches),
      " of ",
      tested,
      " graphs disagree with the ground truth (",
      n_valid_mutants,
      " mutants were themselves valid). First:\n",
      paste(utils::head(mismatches, 10L), collapse = "\n")
    )
  )
})

test_that("is_pag does not depend on node order", {
  # PAG validity is a property of the graph, so declaring the same nodes in a
  # different order must not change the answer. This is a regression test: an
  # earlier `is_pag()` compared the round-tripped graph with `==`, which is
  # sensitive to the orientation symmetric edges happen to be written in, so
  # `A --- C` and `C --- A` compared unequal and the verdict flipped.
  orders <- list(
    c("A", "B", "C", "D", "E"),
    c("E", "D", "C", "B", "A"),
    c("C", "A", "E", "B", "D")
  )
  verdicts <- vapply(
    orders,
    function(ord) {
      is_pag(caugi(
        A %---% C,
        A %---% D,
        A %--o% E,
        B %---% C,
        B %---% D,
        nodes = ord,
        class = "UNKNOWN"
      ))
    },
    logical(1)
  )
  expect_true(all(verdicts))

  # And the same for a graph that is not a PAG.
  invalid <- vapply(
    list(c("A", "B", "C"), c("C", "B", "A")),
    function(ord) {
      is_pag(caugi(A %o->% B, B %o-o% C, nodes = ord, class = "UNKNOWN"))
    },
    logical(1)
  )
  expect_false(any(invalid))
})

test_that("class = 'PAG' is a guarantee", {
  pag <- caugi(A %o->% C, B %o->% C, class = "PAG")
  expect_identical(pag@graph_class, "PAG")
  expect_true(is_pag(pag))
  # A lone `A o-> B` is no PAG: neither endpoint is invariant.
  expect_error(caugi(A %o->% B, class = "PAG"), "invariant marks")
  expect_false(is_pag(caugi(A %o->% B, class = "UNKNOWN")))
})

test_that("AUTO resolves a PAG with circles to 'PAG'", {
  expect_identical(caugi(A %o->% C, B %o->% C)@graph_class, "PAG")
  expect_identical(caugi(A %o->% B)@graph_class, "UNKNOWN")
  # Graphs without circles resolve as before.
  expect_identical(caugi(A %-->% B, B %<->% C)@graph_class, "ADMG")
})

test_that("is_pag rejects self-loops and parallel edges", {
  # The round trip compares one mark pair per node pair, so these must be
  # caught before it.
  expect_false(is_pag(caugi(A %-->% A, class = "UNKNOWN")))
  expect_false(is_pag(caugi(A %o-o% B, A %-->% B, class = "UNKNOWN")))
})

test_that("subgraph re-checks the PAG class", {
  # The complete PAG of a lone edge is `A o-o B`, so `A o-> B` is not one.
  built <- caugi(A %o->% B, C %o->% B, class = "PAG")
  build(built)
  lazy <- caugi(A %o->% B, C %o->% B, class = "PAG")
  for (p in list(built, lazy)) {
    s <- subgraph(p, c("A", "B"))
    expect_identical(s@graph_class, "UNKNOWN")
    expect_false(is_pag(s))
  }
  # A subgraph that is still a PAG keeps the class.
  p <- caugi(A %o->% C, B %o->% C, D, class = "PAG")
  expect_identical(subgraph(p, c("A", "B", "C"))@graph_class, "PAG")
})

test_that("mutate_caugi converts to and from PAG", {
  u <- caugi(A %o->% C, B %o->% C, class = "UNKNOWN")
  expect_identical(mutate_caugi(u, "PAG")@graph_class, "PAG")
  expect_error(
    mutate_caugi(caugi(A %o->% B, class = "UNKNOWN"), "PAG"),
    "Cannot convert"
  )
})
