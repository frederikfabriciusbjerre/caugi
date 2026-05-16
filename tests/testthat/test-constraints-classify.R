# ──────────────────────────────────────────────────────────────────────────────
# ───────────── caugi_constraints — AST classification (skeleton) ──────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# Covers the tier-A edge-atom + boolean classifier introduced in this
# commit. As atoms (adjacency, ancestrality, quantifiers, cardinality)
# come online, sibling test files take them on.

test_that("edge operators classify to edge atoms with the right glyph", {
  ctr <- caugi:::caugi_constraints(A %-->% B, C %---% D, E %<->% F)
  fs <- ctr@formulas
  expect_length(fs, 3L)
  expect_identical(
    fs[[1]],
    list(
      kind = "atom",
      atom = list(kind = "edge", from = "A", to = "B", etype = "-->")
    )
  )
  expect_identical(fs[[2]]$atom$etype, "---")
  expect_identical(fs[[3]]$atom$etype, "<->")
})

test_that("partially-directed edge glyphs round-trip too", {
  ctr <- caugi:::caugi_constraints(A %o->% B, B %--o% C, C %o-o% D)
  glyphs <- vapply(ctr@formulas, function(f) f$atom$etype, character(1))
  expect_identical(glyphs, c("o->", "--o", "o-o"))
})

test_that("negation produces a 'not' node wrapping the classified body", {
  ctr <- caugi:::caugi_constraints(!(D %-->% A))
  expect_identical(ctr@formulas[[1]]$kind, "not")
  expect_identical(
    ctr@formulas[[1]]$body$atom,
    list(kind = "edge", from = "D", to = "A", etype = "-->")
  )
})

test_that("and / or combinators capture both branches", {
  ctr <- caugi:::caugi_constraints(
    (A %-->% B) & (C %-->% D),
    (A %-->% B) | (B %-->% A)
  )
  expect_identical(ctr@formulas[[1]]$kind, "and")
  expect_length(ctr@formulas[[1]]$args, 2L)
  expect_identical(ctr@formulas[[2]]$kind, "or")
})

test_that("&& and || are treated as their vectorised counterparts", {
  ctr_amp <- caugi:::caugi_constraints((A %-->% B) && (C %-->% D))
  ctr_pipe <- caugi:::caugi_constraints((A %-->% B) || (C %-->% D))
  expect_identical(ctr_amp@formulas[[1]]$kind, "and")
  expect_identical(ctr_pipe@formulas[[1]]$kind, "or")
})

test_that("parenthesised forms classify transparently", {
  ctr <- caugi:::caugi_constraints(((A %-->% B)))
  expect_identical(
    ctr@formulas[[1]],
    list(
      kind = "atom",
      atom = list(kind = "edge", from = "A", to = "B", etype = "-->")
    )
  )
})

test_that("string-literal node names are accepted in edge atoms", {
  ctr <- caugi:::caugi_constraints("A" %-->% "B")
  expect_identical(
    ctr@formulas[[1]]$atom,
    list(kind = "edge", from = "A", to = "B", etype = "-->")
  )
})

test_that("nested negation, conjunction, and disjunction compose", {
  ctr <- caugi:::caugi_constraints(
    !((A %-->% B) & ((C %-->% D) | (E %-->% F)))
  )
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "not")
  expect_identical(top$body$kind, "and")
  expect_identical(top$body$args[[2]]$kind, "or")
})

test_that("unrecognised constraint shapes error with a pointer to the design doc", {
  expect_error(
    caugi:::caugi_constraints(some_unknown_fn(A, B)),
    "extras/design/constraints-plan.md"
  )
})

test_that("non-name / non-string leaves in edge atoms error", {
  expect_error(
    caugi:::caugi_constraints((1 + 2) %-->% B),
    "Expected a node name"
  )
})
