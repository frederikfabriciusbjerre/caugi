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

test_that("PAG ancestry follows definite edges only", {
  pag <- caugi(A %o->% C, B %o->% C, C %-->% D, class = "PAG")
  expect_identical(ancestors(pag, "D"), "C")
  expect_identical(descendants(pag, "C"), "D")
  expect_null(ancestors(pag, "C"))
  expect_identical(anteriors(pag, "D"), "C")
  expect_identical(posteriors(pag, "C"), "D")
  expect_setequal(exogenous(pag), c("A", "B", "C"))
})
