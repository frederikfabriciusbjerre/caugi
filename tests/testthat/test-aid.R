# SPDX-License-Identifier: MPL-2.0

# Copies generated from gadjid tests.

cg_from_rc_pd <- function(A) {
  stopifnot(is.matrix(A), nrow(A) == ncol(A))
  n <- nrow(A)
  nm <- colnames(A)
  if (is.null(nm)) {
    nm <- paste0("V", seq_len(n))
  }

  from <- character(0)
  edge <- character(0)
  to <- character(0)

  # directed: row-major, 1 means i -> j
  idx <- which(A == 1L, arr.ind = TRUE)
  if (nrow(idx)) {
    from <- c(from, nm[idx[, 1]])
    edge <- c(edge, rep("-->", nrow(idx)))
    to <- c(to, nm[idx[, 2]])
  }

  # undirected: accept either half, add once
  if (n > 1) {
    for (i in seq_len(n - 1)) {
      for (j in (i + 1):n) {
        if (A[i, j] == 2L || A[j, i] == 2L) {
          from <- c(from, nm[i])
          edge <- c(edge, "---")
          to <- c(to, nm[j])
        }
      }
    }
  }

  caugi(from = from, edge = edge, to = to, nodes = nm, class = "PDAG")
}

cg_from_rc_dag <- function(A) {
  stopifnot(is.matrix(A), nrow(A) == ncol(A))
  n <- nrow(A)
  nm <- colnames(A)
  if (is.null(nm)) {
    nm <- paste0("V", seq_len(n))
  }
  idx <- which(A != 0L, arr.ind = TRUE)
  from <- nm[idx[, 1]]
  to <- nm[idx[, 2]]
  caugi(
    from = from,
    edge = rep("-->", length(from)),
    to = to,
    nodes = nm,
    class = "DAG"
  )
}


test_that("AID wrappers match gadjid_r and known values", {
  # ---- fixtures (copied from gadjid_r tests) ---------------------------------
  cpdag10 <- matrix(0L, 10, 10)
  cpdag10_entries <- cbind(
    row = c(7, 1, 1, 2, 3, 4, 4, 3, 2, 3, 4),
    col = c(2, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10),
    val = c(2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1)
  )
  cpdag10[as.matrix(cpdag10_entries[, 1:2])] <- cpdag10_entries[, 3]

  dag17 <- matrix(0L, 10, 10)
  dag17_entries <- cbind(
    row = c(
      4,
      1,
      3,
      4,
      6,
      7,
      8,
      10,
      1,
      4,
      1,
      2,
      3,
      4,
      6,
      7,
      8,
      9,
      10,
      1,
      3,
      4,
      1,
      3,
      4,
      6,
      1,
      3,
      4,
      6,
      7,
      10,
      1,
      2,
      3,
      4,
      6,
      7,
      8,
      10,
      1,
      3,
      4,
      6,
      7
    ),
    col = c(
      1,
      2,
      2,
      2,
      2,
      2,
      2,
      2,
      3,
      3,
      5,
      5,
      5,
      5,
      5,
      5,
      5,
      5,
      5,
      6,
      6,
      6,
      7,
      7,
      7,
      7,
      8,
      8,
      8,
      8,
      8,
      8,
      9,
      9,
      9,
      9,
      9,
      9,
      9,
      9,
      10,
      10,
      10,
      10,
      10
    )
  )
  dag17[as.matrix(dag17_entries[, 1:2])] <- 1L

  dag18 <- matrix(0L, 10, 10)
  dag18_entries <- cbind(
    row = c(9, 1, 7, 10, 5, 3, 4, 2, 8),
    col = c(1, 3, 4, 5, 6, 7, 8, 9, 10)
  )
  dag18[as.matrix(dag18_entries[, 1:2])] <- 1L

  cpdag19 <- matrix(0L, 10, 10)
  cpdag19_entries <- cbind(
    row = c(9, 7, 2, 1, 6, 9, 3, 6, 3),
    col = c(1, 2, 4, 5, 5, 7, 8, 8, 10),
    val = c(2, 2, 2, 1, 1, 2, 2, 2, 2)
  )
  cpdag19[as.matrix(cpdag19_entries[, 1:2])] <- cpdag19_entries[, 3]

  g_cpdag10 <- cg_from_rc_pd(cpdag10)
  g_dag17 <- cg_from_rc_dag(dag17)
  g_dag18 <- cg_from_rc_dag(dag18)
  g_cpdag19 <- cg_from_rc_pd(cpdag19)

  # ---- expected reference values (from gadjid_r tests) -----------------------
  # ancestor
  expect_equal(
    aid(g_cpdag10, g_dag17, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(
    aid(g_cpdag10, g_dag17, type = "ancestor", normalized = FALSE),
    23
  )
  expect_equal(
    aid(g_dag17, g_dag18, type = "ancestor", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g_dag17, g_dag18, type = "ancestor", normalized = FALSE), 67)

  # oset
  expect_equal(
    aid(g_cpdag10, g_dag17, type = "oset", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g_cpdag10, g_dag17, type = "oset", normalized = FALSE), 23)
  expect_equal(
    aid(g_dag17, g_dag18, type = "oset", normalized = TRUE),
    63 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g_dag17, g_dag18, type = "oset", normalized = FALSE), 63)

  # parent
  expect_equal(
    aid(g_cpdag10, g_dag17, type = "parent", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g_cpdag10, g_dag17, type = "parent", normalized = FALSE), 23)
  expect_equal(
    aid(g_dag17, g_dag18, type = "parent", normalized = TRUE),
    85 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g_dag17, g_dag18, type = "parent", normalized = FALSE), 85)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-CPDAG-16.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 26)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    31 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 31)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    18 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 18)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 33)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    17 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 17)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 34)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 24)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    31 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 31)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 26)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    16 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 16)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    16 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 16)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    16 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 16)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 8)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 20)
})

test_that("small_dag: 10-node-DAG-10.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    18 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 18)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 26)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    29 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 29)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    35 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 35)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 38)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    22 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 22)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 33)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    35 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 35)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 34)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    29 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 29)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    30 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 30)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    30 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 30)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    30 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 30)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 26)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    42 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 42)
})

test_that("small_dag: 10-node-DAG-11.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    22 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 22)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 40)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 21)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    16 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 16)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    17 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 17)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 21)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    15 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 15)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    16 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 16)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 24)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    15 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 15)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    15 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 15)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 24)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 26)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 24)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 21)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 14)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    36 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 36)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 27)
})

test_that("small_dag: 10-node-DAG-12.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    17 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 17)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    14 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 14)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 19)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    44 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 44)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 27)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 46)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 26)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 39)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 27)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    53 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 53)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    29 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 29)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 34)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    53 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 53)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    17 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 17)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    17 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 17)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 40)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    44 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 44)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 39)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    53 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 53)
})

test_that("small_dag: 10-node-DAG-13.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 45)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 49)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 38)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 27)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 40)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 27)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 27)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 49)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    30 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 30)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    32 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 32)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    54 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 54)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    60 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 60)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    19 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 19)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 49)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 25)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 33)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    30 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 30)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 49)
})

test_that("small_dag: 10-node-DAG-14.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 33)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 33)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    54 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 54)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    9 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 9)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 8)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 8)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    11 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 11)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    9 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 9)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    9 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 9)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    4 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 4)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    4 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 4)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    9 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 9)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    10 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 10)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    10 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 10)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 13)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    9 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 9)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 13)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    13 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 13)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    6 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 6)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 8)
})

test_that("small_dag: 10-node-DAG-15.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 8)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 8)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    8 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 8)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-16.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 81)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    83 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 83)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 52)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    54 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 54)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 75)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 49)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 73)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    54 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 54)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    54 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 54)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    83 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 83)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 52)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    74 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 74)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 49)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 49)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    79 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 79)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 81)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    63 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 63)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    85 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 85)
})

test_that("small_dag: 10-node-DAG-17.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 47)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    76 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 76)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 45)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    31 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 31)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    36 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 36)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 20)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 47)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 47)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 49)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    60 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 60)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 46)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    44 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 44)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 46)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    62 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 62)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    44 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 44)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 46)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 45)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 52)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 52)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 52)
})

test_that("small_dag: 10-node-DAG-18.mtx vs 10-node-DAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    43 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 43)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 52)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-CPDAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 25)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(7, 1, 1, 2, 3, 4, 2, 3, 2, 3, 4),
      c(4, 5, 6, 6, 6, 6, 7, 8, 10, 10, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 23)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 4, 10, 6, 9, 5, 7, 10, 3),
      c(1, 1, 1, 1, 5, 6, 7, 7, 8, 8, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    22 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 22)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 26)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 3, 4, 8, 10, 6, 8, 10, 8, 9),
      c(1, 2, 2, 2, 2, 5, 5, 5, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 20)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 10, 7, 9, 10, 3, 6, 7, 9, 1, 6, 7, 10),
      c(2, 3, 3, 4, 4, 4, 5, 5, 6, 7, 8, 8, 8, 8)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 33)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 1, 3, 1, 4, 5, 10, 8, 10, 1, 5, 3, 1),
      c(1, 2, 2, 6, 6, 6, 6, 7, 7, 8, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    29 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 29)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 33)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    31 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 31)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(10, 6, 9, 1, 10, 9), c(1, 3, 3, 5, 5, 8)))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    24 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 24)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    22 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 22)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-16.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 25)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        4,
        1,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        4,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        9,
        10,
        1,
        3,
        4,
        1,
        3,
        4,
        6,
        1,
        3,
        4,
        6,
        7,
        10,
        1,
        2,
        3,
        4,
        6,
        7,
        8,
        10,
        1,
        3,
        4,
        6,
        7
      ),
      c(
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        9,
        10,
        10,
        10,
        10,
        10
      )
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 21)
})

test_that("small_dag: 10-node-DAG-19.mtx vs 10-node-DAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 4, 10, 1, 6, 8, 2, 3, 7),
      c(1, 2, 3, 5, 5, 6, 7, 8, 9)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(9, 1, 7, 10, 5, 3, 4, 2, 8),
      c(1, 3, 4, 5, 6, 7, 8, 9, 10)
    ))] <- 1L
    cg_from_rc_dag(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    17 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 17)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    18 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 18)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 33)
})


test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 37)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 46)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    36 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 36)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 37)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 48)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 37)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    53 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 53)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 46)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 26)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    26 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 26)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    43 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 43)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 71)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 71)
})

test_that("small_cpdag: 10-node-CPDAG-10.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 40)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 46)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 40)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 41)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    50 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 50)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 34)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    35 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 35)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    50 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 50)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 46)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 56)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 37)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 40)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    50 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 50)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    28 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 28)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    28 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 28)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 40)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 73)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 73)
})

test_that("small_cpdag: 10-node-CPDAG-11.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 47)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    60 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 60)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 34)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    35 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 35)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 41)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    32 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 32)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    32 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 32)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 41)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 34)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    34 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 34)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 39)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    35 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 35)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    35 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 35)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    43 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 43)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 21)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    29 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 29)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 75)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 75)
})

test_that("small_cpdag: 10-node-CPDAG-12.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 41)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 41)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 47)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 41)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    59 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 59)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 47)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 47)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    58 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 58)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 40)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    55 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 55)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 52)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    70 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 70)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 37)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 37)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 56)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 67)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 67)
})

test_that("small_cpdag: 10-node-CPDAG-13.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 49)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    49 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 49)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    59 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 59)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    40 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 40)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    52 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 52)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    61 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 61)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    47 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 47)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    58 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 58)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    44 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 44)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    44 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 44)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    62 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 62)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 56)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 56)
})

test_that("small_cpdag: 10-node-CPDAG-14.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    50 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 50)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    61 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 61)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    25 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 25)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    27 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 27)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 23)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    23 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 23)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    20 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 20)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    21 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 21)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    32 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 32)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    32 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 32)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    33 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 33)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    38 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 38)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    37 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 37)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 81)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 81)
})

test_that("small_cpdag: 10-node-CPDAG-15.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 45)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 71)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 73)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 75)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 67)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 56)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 81)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_cpdag: 10-node-CPDAG-17.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 71)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    71 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 71)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 73)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    73 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 73)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 75)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    75 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 75)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 67)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    67 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 67)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 56)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    56 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 56)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 81)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    81 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 81)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 0)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    0 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 0)
})

test_that("small_cpdag: 10-node-CPDAG-18.mtx vs 10-node-CPDAG-19.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-10.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 2, 3, 4, 2, 3, 4), c(6, 6, 6, 6, 10, 10, 10)))] <- 1L
    A[as.matrix(cbind(c(7, 1, 4, 3), c(2, 5, 7, 8)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    39 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 39)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 45)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-11.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(3, 4, 7, 10, 6, 9, 5, 7, 10),
      c(1, 1, 1, 1, 7, 7, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 4, 6), c(3, 5, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    46 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 46)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-12.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(3, 4, 8, 10, 6, 8, 10), c(2, 2, 2, 2, 5, 5, 5)))] <- 1L
    A[as.matrix(cbind(c(3, 9, 9), c(1, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 41)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 41)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 45)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-13.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 10, 7, 9, 10, 3, 6, 1, 6, 7, 10),
      c(3, 3, 4, 4, 4, 5, 5, 8, 8, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(9, 6, 9), c(2, 7, 7)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    36 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 36)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    36 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 36)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    41 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 41)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-14.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 4, 5, 10, 8, 10, 1, 5),
      c(6, 6, 6, 6, 7, 7, 8, 8)
    ))] <- 1L
    A[as.matrix(cbind(c(1, 1, 2, 3, 1), c(2, 3, 3, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    48 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 48)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    53 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 53)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-15.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(6, 9), c(3, 3)))] <- 1L
    A[as.matrix(cbind(c(1, 10, 8, 1), c(5, 5, 9, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    45 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 45)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-17.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(
        2,
        3,
        3,
        6,
        7,
        8,
        9,
        10,
        4,
        5,
        7,
        8,
        10,
        1,
        2,
        5,
        1,
        2,
        6,
        9,
        1,
        3,
        4,
        7,
        8,
        9,
        10,
        1,
        4,
        5,
        8,
        9,
        10,
        1,
        4,
        5,
        9,
        10,
        1,
        3,
        4,
        10,
        1,
        4,
        5
      ),
      c(
        1,
        1,
        2,
        2,
        2,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
        5,
        5,
        5,
        5,
        6,
        6,
        6,
        6,
        6,
        6,
        6,
        7,
        7,
        7,
        7,
        7,
        7,
        8,
        8,
        8,
        8,
        8,
        9,
        9,
        9,
        9,
        10,
        10,
        10
      )
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})

test_that("small_cpdag: 10-node-CPDAG-19.mtx vs 10-node-CPDAG-18.mtx", {
  g1 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(c(1, 6), c(5, 5)))] <- 1L
    A[as.matrix(cbind(c(9, 7, 2, 9, 3, 6, 3), c(1, 2, 4, 7, 8, 8, 10)))] <- 2L
    cg_from_rc_pd(A)
  })
  g2 <- local({
    A <- matrix(0L, 10, 10)
    A[as.matrix(cbind(
      c(1, 7, 6, 4, 4, 1, 2, 5, 8),
      c(3, 3, 5, 7, 8, 9, 9, 10, 10)
    ))] <- 2L
    cg_from_rc_pd(A)
  })
  expect_equal(
    aid(g1, g2, type = "ancestor", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "ancestor", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "oset", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "oset", normalized = FALSE), 51)
  expect_equal(
    aid(g1, g2, type = "parent", normalized = TRUE),
    51 / 90,
    tolerance = 1e-12
  )
  expect_equal(aid(g1, g2, type = "parent", normalized = FALSE), 51)
})
