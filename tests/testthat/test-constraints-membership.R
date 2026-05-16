# ──────────────────────────────────────────────────────────────────────────────
# ────────── caugi_constraints — %in% query() and %<<% precedence ──────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("membership atom: %in% parents(Y) classifies with tier A", {
  ctr <- caugi:::caugi_constraints(A %in% parents(Y))
  expect_identical(
    ctr@formulas[[1]],
    list(
      kind = "atom",
      atom = list(
        kind = "membership",
        elem = "A",
        query = "parents",
        args = list("Y"),
        tier = "A"
      )
    )
  )
})

test_that("membership atom: %in% ancestors(Y) classifies with tier B", {
  ctr <- caugi:::caugi_constraints(A %in% ancestors(Y))
  atom <- ctr@formulas[[1]]$atom
  expect_identical(atom$kind, "membership")
  expect_identical(atom$query, "ancestors")
  expect_identical(atom$tier, "B")
})

test_that("every whitelisted query produces a membership atom", {
  whitelist <- caugi:::.constraint_query_whitelist()
  for (q in names(whitelist)) {
    # Build a one-arg call programmatically so test stays generic.
    expr <- bquote(A %in% .(as.name(q))(Y))
    ctr <- eval(bquote(caugi:::caugi_constraints(.(expr))))
    atom <- ctr@formulas[[1]]$atom
    expect_identical(atom$query, q)
    expect_identical(atom$tier, whitelist[[q]])
  }
})

test_that("membership args support c(...) sets", {
  ctr <- caugi:::caugi_constraints(A %in% ancestors(c(Y, Z)))
  atom <- ctr@formulas[[1]]$atom
  expect_identical(atom$args, list(c("Y", "Z")))
})

test_that("unknown query on rhs of %in% errors with the whitelist", {
  expect_error(
    caugi:::caugi_constraints(A %in% not_a_query(Y)),
    "Unrecognized query function"
  )
})

test_that("a literal `c(...)` set on rhs of %in% is not a query and errors", {
  # `c(...)` is a call, so this hits the whitelist branch rather than the
  # non-call branch — the user still gets a clear error pointing at the
  # whitelist.
  expect_error(
    caugi:::caugi_constraints(A %in% c("X", "Y")),
    "Unrecognized query function `c\\(\\)`"
  )
})

test_that("a bare-name rhs of %in% (no call) errors", {
  expect_error(
    caugi:::caugi_constraints(A %in% Y),
    "must be a query call"
  )
})

test_that("query with zero arguments errors", {
  expect_error(
    caugi:::caugi_constraints(A %in% parents()),
    "requires at least one node argument"
  )
})

test_that("negated membership wraps the atom in 'not'", {
  ctr <- caugi:::caugi_constraints(!(D %in% ancestors(A)))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "not")
  expect_identical(top$body$atom$query, "ancestors")
  expect_identical(top$body$atom$elem, "D")
})

# ── %<<% topological precedence ──────────────────────────────────────────────

test_that("%<<% on single-name sides desugars to one negated ancestor atom", {
  ctr <- caugi:::caugi_constraints(A %<<% B)
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "not")
  atom <- top$body$atom
  expect_identical(atom$kind, "membership")
  expect_identical(atom$query, "ancestors")
  expect_identical(atom$elem, "B")
  expect_identical(atom$args, list("A"))
})

test_that("%<<% with multi-element sets emits the cartesian product", {
  ctr <- caugi:::caugi_constraints(c(A) %<<% c(B, C))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "and")
  expect_length(top$args, 2L)
  # Atom 1: !(B %in% ancestors(A))
  expect_identical(top$args[[1]]$body$atom$elem, "B")
  expect_identical(top$args[[1]]$body$atom$args, list("A"))
  # Atom 2: !(C %in% ancestors(A))
  expect_identical(top$args[[2]]$body$atom$elem, "C")
  expect_identical(top$args[[2]]$body$atom$args, list("A"))
})

test_that("%<<% chains expand into adjacent-pair desugarings", {
  ctr <- caugi:::caugi_constraints(c(A) %<<% c(B, C) %<<% c(D))
  top <- ctr@formulas[[1]]
  expect_identical(top$kind, "and")
  # (A,B), (A,C) from first segment, (B,D), (C,D) from second segment
  expect_length(top$args, 4L)
  elems <- vapply(top$args, function(a) a$body$atom$elem, character(1))
  parents_of <- vapply(top$args, function(a) a$body$atom$args[[1]], character(1))
  expect_setequal(paste(parents_of, elems, sep = "->"),
                  c("A->B", "A->C", "B->D", "C->D"))
})

test_that("%<<% composes with other constraints", {
  ctr <- caugi:::caugi_constraints(
    A %-->% B,
    c(A) %<<% c(B)
  )
  expect_length(ctr@formulas, 2L)
  expect_identical(ctr@formulas[[1]]$atom$kind, "edge")
  expect_identical(ctr@formulas[[2]]$kind, "not")
})

test_that("`%<<%` called outside a constraint errors with a pointer", {
  expect_error(
    caugi:::`%<<%`("A", "B"),
    "only meaningful inside"
  )
})
