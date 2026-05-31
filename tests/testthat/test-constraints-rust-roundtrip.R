# ──────────────────────────────────────────────────────────────────────────────
# ──────────── caugi_constraints — R AST round-trip through Rust ───────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# Smoke tests that the R-side classifier output parses cleanly into the
# Rust `Formula` type. The evaluator isn't wired up yet, so we assert on
# the Rust `Debug` rendering of each parsed formula.

# Build constraints, then ship each formula through Rust.
.rt <- function(...) {
  ctr <- caugi:::caugi_constraints(...)
  vapply(
    ctr@formulas,
    caugi:::.constraints_parse_formula_rs,
    character(1L)
  )
}

test_that("edge atoms parse into the Edge variant", {
  out <- .rt(A %-->% B)
  expect_match(out, "Atom\\(Edge")
  expect_match(out, '"A"')
  expect_match(out, '"B"')
  expect_match(out, '"-->"')
})

test_that("every edge glyph round-trips", {
  out <- .rt(A %-->% B, A %---% B, A %<->% B, A %o->% B, A %--o% B, A %o-o% B)
  expect_length(out, 6L)
  glyphs <- c("-->", "---", "<->", "o->", "--o", "o-o")
  for (i in seq_along(glyphs)) {
    expect_match(out[i], paste0('"', glyphs[i], '"'), fixed = TRUE)
  }
})

test_that("negation / and / or wrap inner formulas", {
  out <- .rt(
    !(A %-->% B),
    (A %-->% B) & (C %-->% D),
    (A %-->% B) | (C %-->% D)
  )
  expect_match(out[1], "Not\\(Atom\\(Edge")
  expect_match(out[2], "And\\(\\[")
  expect_match(out[3], "Or\\(\\[")
})

test_that("xor / implies parse into their dedicated variants", {
  out <- .rt(
    xor(A %-->% B, B %-->% A),
    implies(A %in% ancestors(Y), !(Y %-->% A))
  )
  expect_match(out[1], "Xor\\(")
  expect_match(out[2], "Implies\\(")
})

test_that("membership atoms carry query, args, and tier", {
  out <- .rt(A %in% parents(Y), B %in% ancestors(c(X, Y)))
  expect_match(out[1], "Membership")
  expect_match(out[1], '"parents"')
  expect_match(out[1], "tier: A")
  expect_match(out[2], "tier: B")
  expect_match(out[2], '"X"')
  expect_match(out[2], '"Y"')
})

test_that("standalone predicates round-trip", {
  out <- .rt(
    acyclic(),
    collider(A, B, C),
    v_structure(A, B, C),
    dsep(X, Y, c(Z1, Z2))
  )
  expect_match(out[1], "Acyclic")
  expect_match(out[2], "Collider")
  expect_match(out[3], "VStructure")
  expect_match(out[4], "Dsep")
  expect_match(out[4], '"Z1"')
})

test_that("quantifiers preserve bound-variable names and scope", {
  out <- .rt(
    forall(X, X %-->% Y),
    exists(c(Z1, Z2), Z1 %-->% Z2)
  )
  expect_match(out[1], "Forall")
  expect_match(out[1], 'vars: \\["X"\\]')
  expect_match(out[1], "AllNodes")
  expect_match(out[2], "Exists")
  expect_match(out[2], 'vars: \\["Z1", "Z2"\\]')
})

test_that("cardinality: formula-set form parses with all formulas", {
  out <- .rt(at_most(2, c(A %-->% Y, B %-->% Y, C %-->% Y)))
  expect_match(out, "Cardinality")
  expect_match(out, "AtMost")
  expect_match(out, "k: 2")
  expect_match(out, "Formulas\\(\\[")
})

test_that("cardinality: query-set form parses with query name + tier", {
  out <- .rt(at_most(3, parents(Y)))
  expect_match(out, "Cardinality")
  expect_match(out, "Query")
  expect_match(out, '"parents"')
  expect_match(out, "tier: A")
})

test_that("at_least and exactly variants are distinguishable", {
  out <- .rt(
    at_least(1, c(A %-->% Y)),
    exactly(0, c(A %-->% Y))
  )
  expect_match(out[1], "AtLeast")
  expect_match(out[2], "Exactly")
})

test_that("nested formulas (quantifier wrapping cardinality) parse cleanly", {
  out <- .rt(forall(X, at_most(3, parents(X))))
  expect_match(out, "Forall")
  expect_match(out, "Cardinality")
  expect_match(out, "Query")
})

test_that("topological precedence (%<<%) round-trips through Rust as ancestor membership", {
  out <- .rt(c(A, B) %<<% c(C, D))
  # Desugars to an And of four `!(... %in% ancestors(...))` membership
  # atoms, all tier B.
  expect_match(out, "And\\(\\[")
  expect_match(out, "Membership")
  expect_match(out, '"ancestors"')
  expect_match(out, "tier: B")
})

test_that("malformed AST (manually constructed) errors clearly from Rust", {
  bogus <- list(kind = "no_such_kind")
  expect_error(
    caugi:::.constraints_parse_formula_rs(bogus),
    "Unknown formula kind"
  )
})
