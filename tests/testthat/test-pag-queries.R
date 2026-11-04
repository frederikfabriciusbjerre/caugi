# Queries on a PAG read definite marks only: a circle is neither a tail nor
# an arrowhead, so `o->`, `--o` and `o-o` edges add no parents, children or
# ancestors.

test_that("PAG neighbour queries split edges by their marks", {
  # The PAG of the collider A --> C <-- B with C --> D.
  pag <- caugi(A %o->% C, B %o->% C, C %-->% D, class = "PAG")
  expect_identical(pag@graph_class, "PAG")

  expect_null(parents(pag, "C"))
  expect_identical(parents(pag, "D"), "C")
  expect_identical(children(pag, "C"), "D")
  expect_setequal(neighbors(pag, "C"), c("A", "B", "D"))
  expect_setequal(neighbors(pag, "C", mode = "partial"), c("A", "B"))
  expect_null(neighbors(pag, "C", mode = "bidirected"))

  # An uncovered undirected cycle is invariant (R5): selection on all four.
  sel <- caugi(A %---% C, C %---% B, B %---% D, D %---% A, class = "PAG")
  expect_setequal(neighbors(sel, "A", mode = "undirected"), c("C", "D"))
  expect_setequal(anteriors(sel, "A"), c("B", "C", "D"))
})

test_that("PAG Markov blanket is that of every member MAG", {
  pag <- caugi(A %o->% C, B %o->% C, C %-->% D, class = "PAG")
  expect_setequal(markov_blanket(pag, "A"), c("B", "C"))
  expect_setequal(markov_blanket(pag, "C"), c("A", "B", "D"))
  expect_identical(markov_blanket(pag, "D"), "C")

  # The MAG a PAG came from need not be the member pag_to_mag() picks.
  set.seed(20261104)
  for (i in 1:50) {
    dag <- generate_graph(n = 8, p = 0.3, class = "DAG")
    latents <- sample(nodes(dag)$name, 2)
    mag <- condition_marginalize(dag, marg_vars = latents)
    pag <- dag_to_pag(dag, latents = latents)
    for (v in nodes(pag)$name) {
      expect_setequal(
        as.character(markov_blanket(pag, v)),
        as.character(markov_blanket(mag, v))
      )
    }
  }
})

test_that("PAG ancestry follows definite edges only", {
  pag <- caugi(A %o->% C, B %o->% C, C %-->% D, class = "PAG")
  expect_identical(ancestors(pag, "D"), "C")
  expect_identical(descendants(pag, "C"), "D")
  expect_null(ancestors(pag, "C"))
  expect_identical(anteriors(pag, "D"), "C")
  expect_identical(posteriors(pag, "C"), "D")
  expect_setequal(exogenous(pag), c("A", "B", "C"))
})
