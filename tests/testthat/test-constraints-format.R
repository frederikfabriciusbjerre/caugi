# ──────────────────────────────────────────────────────────────────────────────
# ──────────────── caugi_constraints — print / format methods ──────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("empty constraints format with a recognisable header", {
  ctr <- caugi:::caugi_constraints()
  expect_match(format(ctr), "empty")
})

test_that("singular vs plural agrees with the formula count", {
  expect_match(format(caugi:::caugi_constraints(A %-->% B)), "1 formula\\b")
  expect_match(
    format(caugi:::caugi_constraints(A %-->% B, C %-->% D)),
    "2 formulas"
  )
})

test_that("edge atoms render back to %glyph% surface syntax", {
  out <- format(caugi:::caugi_constraints(A %-->% B, C %<->% D))
  expect_match(out, "A %-->% B")
  expect_match(out, "C %<->% D")
})

test_that("negation renders as ! around the body", {
  out <- format(caugi:::caugi_constraints(!(D %-->% A)))
  expect_match(out, "!")
  expect_match(out, "D %-->% A")
})

test_that("membership atoms render via %in% query()", {
  out <- format(caugi:::caugi_constraints(A %in% ancestors(Y)))
  expect_match(out, "A %in% ancestors\\(Y\\)")
})

test_that("standalone predicates render with their canonical names", {
  out <- format(caugi:::caugi_constraints(
    acyclic(),
    collider(A, B, C),
    v_structure(A, B, C),
    dsep(X, Y, Z)
  ))
  expect_match(out, "acyclic\\(\\)")
  expect_match(out, "collider\\(A, B, C\\)")
  expect_match(out, "v_structure\\(A, B, C\\)")
  expect_match(out, "dsep\\(X, Y, Z\\)")
})

test_that("quantifiers render with the bound-variable spec", {
  out <- format(caugi:::caugi_constraints(forall(X, X %-->% Y)))
  expect_match(out, "forall\\(X, X %-->% Y\\)")
  out2 <- format(caugi:::caugi_constraints(
    forall(c(X, Y, Z), (X %-->% Y) & (Y %-->% Z))
  ))
  expect_match(out2, "forall\\(c\\(X, Y, Z\\)")
})

test_that("cardinality renders both formula-set and query-set forms", {
  out <- format(caugi:::caugi_constraints(
    at_most(2, c(A %-->% Y, B %-->% Y)),
    at_most(3, parents(Y))
  ))
  expect_match(out, "at_most\\(2, c\\(A %-->% Y, B %-->% Y\\)\\)")
  expect_match(out, "at_most\\(3, parents\\(Y\\)\\)")
})

test_that("xor and implies render with named call syntax", {
  out <- format(caugi:::caugi_constraints(
    xor(A %-->% B, B %-->% A),
    implies(A %in% ancestors(Y), !(Y %-->% A))
  ))
  expect_match(out, "xor\\(A %-->% B, B %-->% A\\)")
  expect_match(out, "implies\\(A %in% ancestors\\(Y\\)")
})

test_that("print returns the object invisibly and writes to stdout", {
  ctr <- caugi:::caugi_constraints(A %-->% B)
  expect_output(returned <- print(ctr), "A %-->% B", fixed = TRUE)
  expect_identical(returned, ctr)
})
