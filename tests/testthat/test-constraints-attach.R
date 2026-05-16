# ──────────────────────────────────────────────────────────────────────────────
# ─────────── caugi_constraints — attach to a caugi via with_constraints ──────
# ──────────────────────────────────────────────────────────────────────────────

test_that("with_constraints() returns a caugi carrying the attached set", {
  cg <- caugi(A %-->% B, class = "DAG")
  ctr <- caugi:::caugi_constraints(A %-->% B)
  cg2 <- caugi:::with_constraints(cg, ctr)
  expect_true(S7::S7_inherits(cg2, caugi))
  expect_identical(caugi:::constraints(cg2), ctr)
})

test_that("constraints() returns NULL when nothing is attached", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_null(caugi:::constraints(cg))
})

test_that("with_constraints() replaces a previously-attached set", {
  cg <- caugi(A %-->% B, class = "DAG")
  ctr1 <- caugi:::caugi_constraints(A %-->% B)
  ctr2 <- caugi:::caugi_constraints(B %-->% A)
  cg2 <- caugi:::with_constraints(cg, ctr1)
  cg3 <- caugi:::with_constraints(cg2, ctr2)
  expect_identical(caugi:::constraints(cg3), ctr2)
})

test_that("with_constraints() validates its inputs", {
  cg <- caugi(A %-->% B, class = "DAG")
  expect_error(
    caugi:::with_constraints("not a caugi", caugi:::caugi_constraints()),
    "caugi"
  )
  expect_error(
    caugi:::with_constraints(cg, "not a constraint"),
    "must be a `caugi_constraints` object"
  )
})

test_that("constraints() validates its caugi input", {
  expect_error(caugi:::constraints("not a caugi"), "caugi")
})

test_that("with_constraints() round-trips boolean-algebra results", {
  cg <- caugi(A %-->% B, class = "DAG")
  ctr <- caugi:::caugi_constraints(A %-->% B) &
    caugi:::caugi_constraints(B %-->% C)
  cg2 <- caugi:::with_constraints(cg, ctr)
  got <- caugi:::constraints(cg2)
  expect_length(got@formulas, 2L)
  expect_identical(got@formulas[[2]]$atom$to, "C")
})
