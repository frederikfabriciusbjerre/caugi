# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────── Edge operators tests ─────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Expand targets ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".expand_targets handles symbols, +, c(), and character", {
  expect_equal(.expand_targets(quote(B)), "B")
  expect_equal(.expand_targets(quote(B + C + D)), c("B", "C", "D"))
  expect_equal(.expand_targets(quote(c(B, C, "D"))), c("B", "C", "D"))
  expect_equal(.expand_targets(quote(c(B + C, D))), c("B", "C", "D"))
  expect_equal(.expand_targets(1L), "1")
})

test_that(".expand_targets errors on unsupported RHS forms", {
  expect_error(
    .edge_spec(quote(A), quote(paste(B, C))),
    "Unsupported right-hand side"
  )
  expect_error(
    .edge_spec(quote(A), quote(1:3)),
    "Unsupported right-hand side"
  )
  expect_error(
    .edge_spec(
      quote(A),
      quote({
        B
      })
    ),
    "Unsupported right-hand side"
  )
  expect_error(
    .edge_spec(quote(A), quote(B * C)),
    "Unsupported right-hand side"
  )
  expect_error(
    .edge_spec(quote(A), quote(TRUE)),
    "Unsupported right-hand side"
  )
  expect_error(
    .edge_spec(quote(A), quote(NULL)),
    "Unsupported right-hand side"
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────── Edge builder ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that(".edge_spec builds a data frame with class 'caugi_edge_spec'", {
  sp <- .edge_spec(quote(A), quote(c(B, C)), "-->")
  expect_equal(sp$from, c("A", "A"))
  expect_equal(sp$to, c("B", "C"))
  expect_equal(sp$edge, c("-->", "-->"))
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── Infix operators ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("infix operators emit correct glyphs and rows", {
  s1 <- A %-->% (B + C)
  s2 <- A %<->% B
  s3 <- A %---% c(B, C, D)
  s4 <- A %o-o% "Z"
  s5 <- A %--o% (B + "C")
  s6 <- A %o->% c(B, "C")
  expect_equal(unique(s1$edge), "-->")
  expect_equal(unique(s2$edge), "<->")
  expect_equal(unique(s3$edge), "---")
  expect_equal(unique(s4$edge), "o-o")
  expect_equal(unique(s5$edge), "--o")
  expect_equal(unique(s6$edge), "o->")
  expect_equal(nrow(s1), 2L)
  expect_equal(nrow(s2), 1L)
  expect_equal(nrow(s3), 3L)
  expect_equal(nrow(s4), 1L)
  expect_equal(nrow(s5), 2L)
  expect_equal(nrow(s6), 2L)
  expect_equal(s1$from, rep("A", 2))
  expect_equal(s3$to, c("B", "C", "D"))
})
