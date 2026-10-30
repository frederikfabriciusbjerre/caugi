test_that("the 4-node ground truth has every MAG and equivalence class", {
  skip_on_cran()
  gt <- .pag_ground_truth()
  # The counts ggm's m-separation gives when the same enumeration runs on it.
  expect_length(gt$mags, 3045L)
  expect_length(gt$pags, 251L)
  # Markov equivalent MAGs share a skeleton, and PAGs are 1:1 with classes.
  for (cl in gt$classes) {
    skel <- lapply(gt$mags[cl], function(A) A != 0L)
    expect_true(all(vapply(skel, identical, TRUE, skel[[1]])))
  }
  expect_false(anyDuplicated(gt$keys) > 0L)
})

test_that("caugi's m-separation agrees with ggm on the 4-node MAGs", {
  skip_on_cran()
  skip_if_not_installed("ggm")
  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  bad <- character(0)
  # Every 10th MAG: ggm takes about 10 ms per MAG for all 24 queries.
  for (r in seq(1L, length(gt$mags), by = 10L)) {
    # ggm's coding: 1 for row --> col, 100 for <->, 10 for ---.
    A <- gt$mags[[r]]
    g <- matrix(0, gt$n, gt$n, dimnames = list(nms, nms))
    g[A == 2L & t(A) == 3L] <- 1
    g[A == 2L & t(A) == 2L] <- 100
    g[A == 3L & t(A) == 3L] <- 10
    ggm_sep <- vapply(
      gt$queries,
      function(q) ggm::msep(g, nms[q$i], nms[q$j], nms[q$S]),
      TRUE
    )
    if (!identical(ggm_sep, gt$msep[r, ])) {
      bad <- c(bad, sprintf("MAG %d", r))
    }
  }
  expect_identical(head(bad, 10L), character(0))
})
