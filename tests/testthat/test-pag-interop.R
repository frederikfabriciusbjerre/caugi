# PAGs through matrices, files and dagitty, and the degenerate PAGs.

test_that("every 4-node PAG round-trips through matrices, data.frames and files", {
  skip_on_cran()

  gt <- .pag_ground_truth()
  nms <- paste0("N", seq_len(gt$n))
  dir <- withr::local_tempdir()
  bad <- character(0)

  for (k in seq_along(gt$pags)) {
    P <- gt$pags[[k]]
    storage.mode(P) <- "integer"
    dimnames(P) <- list(nms, nms)
    pag <- .amat_pag_to_caugi(P, nms, class = "PAG")

    # The exporter reproduces the ground truth's matrix, which pins the
    # convention from both ends: the code is the mark at the column node.
    m <- as_adjacency(pag, coding = "marks")
    json <- file.path(dir, "pag.caugi.json")
    write_caugi(pag, json)
    xml <- file.path(dir, "pag.graphml")
    write_graphml(pag, xml)

    ok <- identical(m, P) &&
      as_caugi(m, class = "PAG") == pag &&
      as_caugi(as.data.frame(pag)) == pag &&
      read_caugi(json) == pag &&
      read_graphml(xml) == pag
    if (!ok) {
      bad <- c(bad, sprintf("PAG %d", k))
    }
  }
  expect_identical(head(bad, 10L), character(0))
})

test_that("the causality-lab adjacency fixture round-trips", {
  # From causality-lab's `test_get_adj_mat` / `test_init_from_adj_mat`: ten
  # nodes, eleven edges in the same 0-3 mark coding, all `o-o` bar two `o->`.
  nms <- paste0("N", 0:9)
  M <- matrix(0L, 10, 10, dimnames = list(nms, nms))
  circle <- rbind(
    c(3, 4),
    c(4, 6),
    c(5, 0),
    c(0, 8),
    c(1, 2),
    c(2, 9),
    c(7, 5),
    c(7, 8),
    c(5, 8)
  ) +
    1L
  arrow <- rbind(c(4, 5), c(8, 1)) + 1L
  M[circle] <- 1L
  M[circle[, 2:1]] <- 1L
  M[arrow] <- 2L # arrowhead at the second node
  M[arrow[, 2:1]] <- 1L # circle at the first
  expect_equal(sum(M > 0L), 11L * 2L)

  # Not a complete PAG, so it reads back as UNKNOWN.
  cg <- as_caugi(M, class = "UNKNOWN")
  expect_equal(nrow(edges(cg)), 11L)
  expect_setequal(unique(edges(cg)$edge), c("o-o", "o->"))
  expect_identical(as_adjacency(cg, coding = "marks"), M)
})

test_that("a PAG round-trips through dagitty", {
  skip_if_not_installed("dagitty")
  pag <- mag_to_pag(caugi(A %-->% C, B %-->% C, class = "AG"))
  d <- as_dagitty(pag)
  expect_identical(dagitty::graphType(d), "pag")
  expect_true(as_caugi(d, class = "PAG") == pag)
})

test_that("degenerate PAGs behave", {
  # An empty graph and isolated nodes are valid PAGs.
  for (n in 0:2) {
    cg <- caugi(nodes = paste0("N", seq_len(n)), class = "PAG")
    expect_identical(cg@graph_class, "PAG")
    expect_true(is_pag(cg))
  }
})

test_that("a complete all-circle graph is a valid PAG", {
  # With a complete skeleton every orientation is Markov equivalent, so no
  # endpoint is invariant.
  for (n in 2:4) {
    prs <- utils::combn(paste0("N", seq_len(n)), 2)
    cg <- caugi(
      from = prs[1, ],
      edge = rep("o-o", ncol(prs)),
      to = prs[2, ],
      class = "PAG"
    )
    expect_true(mag_to_pag(pag_to_mag(cg)) == cg)
  }
})

test_that("an undirected cycle is a valid PAG but a triangle is not", {
  # Orienting a four-cycle of `---` edges any other way creates an unshielded
  # collider, so the tails are invariant.
  cg <- caugi(A %---% B, B %---% D, D %---% C, C %---% A, class = "PAG")
  expect_true(is_pag(cg))
  # A triangle is complete, so a complete DAG is equivalent to it and its
  # tails are not invariant; the same holds for a lone edge.
  expect_error(
    caugi(A %---% B, B %---% C, A %---% C, class = "PAG"),
    "invariant marks"
  )
  expect_error(caugi(A %---% B, class = "PAG"), "invariant marks")
})
