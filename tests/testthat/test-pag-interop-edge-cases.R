# PAG interop with other representations, and the degenerate graphs.

test_that("the causality-lab adjacency fixture round-trips", {
  # From `causality-lab`'s `test_get_adj_mat` / `test_init_from_adj_mat`: ten
  # nodes, eleven edges, in the same 0-3 mark coding caugi reads. Their graph
  # is all `o-o` bar two `o->` edges.
  nms <- paste0("N", 0:9)
  M <- matrix(0L, 10, 10, dimnames = list(nms, nms))
  circle <- list(
    c(3, 4),
    c(4, 6),
    c(5, 0),
    c(0, 8),
    c(1, 2),
    c(2, 9),
    c(7, 5),
    c(7, 8),
    c(5, 8)
  )
  arrow <- list(c(4, 5), c(8, 1))
  for (e in circle) {
    M[e[1] + 1L, e[2] + 1L] <- 1L
    M[e[2] + 1L, e[1] + 1L] <- 1L
  }
  for (e in arrow) {
    M[e[1] + 1L, e[2] + 1L] <- 2L # arrowhead at the second
    M[e[2] + 1L, e[1] + 1L] <- 1L # circle at the first
  }

  # Eleven edges, as their test asserts.
  expect_equal(sum(M > 0L), 11L * 2L)

  # Built from the edge list rather than decoded from `M`: a matrix mixing
  # circle codes with arrowheads requires `class = "PAG"`, which validates,
  # and this hand-built test graph is not a genuine PAG. The export direction
  # is what is checked here -- the import direction is covered over all 251
  # valid PAGs in `test-pag-amat-round-trip.R`.
  from <- c(
    vapply(circle, function(e) nms[e[1] + 1L], character(1)),
    vapply(arrow, function(e) nms[e[1] + 1L], character(1))
  )
  to <- c(
    vapply(circle, function(e) nms[e[2] + 1L], character(1)),
    vapply(arrow, function(e) nms[e[2] + 1L], character(1))
  )
  cg <- caugi(
    from = from,
    edge = c(rep("o-o", length(circle)), rep("o->", length(arrow))),
    to = to,
    nodes = nms,
    class = "UNKNOWN"
  )
  expect_equal(nrow(edges(cg)), 11L)
  expect_setequal(unique(edges(cg)$edge), c("o-o", "o->"))
  expect_equal(as_adjacency(cg, coding = "marks"), M)
})

test_that("a PAG round-trips through dagitty", {
  skip_if_not_installed("dagitty")

  pag <- mag_to_pag(caugi(A %-->% C, B %-->% C, class = "AG"))
  d <- as_dagitty(pag)
  expect_identical(dagitty::graphType(d), "pag")

  back <- as_caugi(d, class = "PAG")
  expect_true(back == pag)
})

test_that("degenerate PAGs behave", {
  # An empty graph and a single isolated node are both valid PAGs.
  for (n in 0:2) {
    nm <- if (n == 0L) character(0) else paste0("N", seq_len(n))
    cg <- caugi(nodes = nm, class = "PAG")
    expect_identical(cg@graph_class, "PAG")
    expect_equal(nrow(edges(cg)), 0L)
    expect_true(is_pag(cg))
  }
})

test_that("a complete all-circle graph is a valid PAG", {
  # Every orientation is Markov equivalent when the skeleton is complete, so
  # no endpoint is invariant and the PAG is all circles.
  for (n in 2:4) {
    nms <- paste0("N", seq_len(n))
    prs <- combn(nms, 2, simplify = FALSE)
    cg <- caugi(
      from = vapply(prs, `[`, character(1), 1),
      edge = rep("o-o", length(prs)),
      to = vapply(prs, `[`, character(1), 2),
      nodes = nms,
      class = "PAG"
    )
    expect_true(is_pag(cg))
    # It is the PAG of some MAG, and the round trip must return it.
    expect_true(mag_to_pag(pag_to_mag(cg)) == cg)
  }
})

test_that("an undirected cycle is a valid PAG but a triangle is not", {
  # A four-cycle of `---` edges is the only all-undirected shape that survives
  # at four nodes: any orientation of it creates an unshielded collider, which
  # is what makes the tails invariant.
  cg <- caugi(A %---% B, B %---% D, D %---% C, C %---% A, class = "PAG")
  expect_true(is_pag(cg))
  expect_setequal(unique(edges(cg)$edge), "---")

  # A triangle is complete, so it encodes no independences and a complete DAG
  # is Markov equivalent to it. The tails are therefore not invariant and the
  # PAG of that MAG is all circles.
  expect_error(
    caugi(A %---% B, B %---% C, A %---% C, class = "PAG"),
    "invariant marks"
  )
  # Same reason for a lone edge.
  expect_error(caugi(A %---% B, class = "PAG"), "invariant marks")
})
