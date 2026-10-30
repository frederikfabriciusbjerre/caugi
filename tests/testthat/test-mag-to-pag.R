test_that("mag_to_pag gives every 4-node MAG the PAG of its class", {
  skip_on_cran()

  # The ground truth's PAGs come from the definition: a mark is definite iff
  # every MAG in the class shares it.
  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  bad <- character(0)
  for (k in seq_along(gt$classes)) {
    want <- gt$pags[[k]]
    storage.mode(want) <- "integer"
    dimnames(want) <- list(nms, nms)
    for (r in gt$classes[[k]]) {
      mag <- .amat_pag_to_caugi(gt$mags[[r]], nms, class = "AG")
      got <- as_adjacency(mag_to_pag(mag), coding = "marks")
      if (!identical(got, want)) {
        bad <- c(bad, sprintf("MAG %d (class %d)", r, k))
      }
    }
  }
  expect_identical(head(bad, 10L), character(0))
})

test_that("mag_to_pag keeps exactly the invariant marks", {
  pag <- mag_to_pag(caugi(A %-->% B, C %-->% B, class = "AG"))
  expect_setequal(paste(edges(pag)$from, edges(pag)$edge), c("A o->", "C o->"))

  chain <- mag_to_pag(caugi(A %-->% B, B %-->% C, class = "AG"))
  expect_true(all(edges(chain)$edge == "o-o"))
})

test_that("mag_to_pag needs a maximal ancestral graph", {
  expect_error(
    mag_to_pag(caugi(A %-->% B, class = "DAG")),
    "class 'AG'"
  )
  # C <-> A <-> B <-> D is an inducing path between C and D: A --> D and
  # B --> C make both colliders ancestors of an endpoint.
  not_maximal <- caugi(
    A %-->% D,
    B %<->% A,
    B %-->% C,
    B %<->% D,
    C %<->% A,
    class = "AG"
  )
  expect_false(is_mag(not_maximal))
  expect_error(mag_to_pag(not_maximal), "not maximal")
})
