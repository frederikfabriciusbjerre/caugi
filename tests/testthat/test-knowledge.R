test_that("knowledge() reads statements, node sets and bare nodes", {
  bk <- knowledge(A + B %!-->% C + D, exogenous(A, "B"), E)
  expect_equal(nodes(bk)$name, c("E", "A", "B", "C", "D"))
  expect_equal(nrow(edges(bk)), 4L)
  expect_equal(nodes(bk)$exogenous, c(FALSE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(edges(knowledge(A %-->% c(B, C)))$to, c("B", "C"))
  expect_equal(nrow(edges(knowledge(A %-->% B %!-->% C))), 2L)
  expect_equal(nrow(edges(knowledge(A %-->% B + C %-->% D))), 2L)
  expect_equal(
    nodes(knowledge(A, "B", nodes = c("A", "B", "C")))$name,
    c("A", "B", "C")
  )
  expect_equal(nrow(edges(knowledge())), 0L)
})

test_that("tier() names tiers and evaluates max_lag", {
  lag <- 2
  bk <- knowledge(tier(A, late = B, C, max_lag = lag))
  expect_equal(tiers(bk), list(`1` = "A", late = "B", `3` = "C"))
  expect_identical(rs_kn_tiers(bk@ptr)$max_lag, 2L)
  expect_true(is.na(rs_kn_tiers(knowledge(tier(A, B))@ptr)$max_lag))
})

test_that("is_knowledge(), tiers(), nodes() and edges() read knowledge", {
  bk <- knowledge(tier(t1 = A, t2 = B), A %-->% B, exogenous(A))
  expect_true(is_knowledge(bk))
  expect_false(is_knowledge(caugi(A %-->% B)))
  expect_error(is_knowledge(1, throw_error = TRUE), "knowledge")
  expect_error(tiers(caugi(A %-->% B)), "knowledge")
  expect_equal(
    as.data.frame(nodes(bk)),
    data.frame(
      name = c("A", "B"),
      tier = c("t1", "t2"),
      exogenous = c(TRUE, FALSE)
    )
  )
  expect_equal(
    nodes(knowledge(A %-->% B))$tier,
    c(NA_character_, NA_character_)
  )
  # edges() returns a copy.
  e <- edges(bk)
  e[1, "to"] <- "A"
  expect_equal(edges(bk)$to, "B")
})

test_that("edges(expand = TRUE) gives the tightest statement per pair", {
  bk <- knowledge(
    A %!---% B,
    C %-->% D,
    F %-->% E,
    G %---% H,
    I %!-->% J,
    L %!-->% K
  )
  expect_equal(
    as.data.frame(edges(bk, expand = TRUE)),
    data.frame(
      from = c("A", "C", "F", "G", "I", "L"),
      edge = c("!---", "-->", "-->", "---", "!-->", "!-->"),
      to = c("B", "D", "E", "H", "J", "K")
    )
  )
  # Both directions ruled out means not adjacent.
  expect_equal(
    edges(knowledge(tier(A, B), A %!-->% B), expand = TRUE)$edge,
    "!---"
  )
  expect_equal(edges(knowledge(exogenous(A, B)), expand = TRUE)$edge, "!---")
  # A tier and adjacency force a direction.
  expect_equal(
    as.data.frame(edges(knowledge(tier(A, B), B %---% A), expand = TRUE)),
    data.frame(from = "A", edge = "-->", to = "B")
  )
  # max_lag rules out far pairs only.
  far <- edges(knowledge(tier(A, B, C, max_lag = 1)), expand = TRUE)
  expect_equal(far$edge, c("!---", "!-->", "!-->"))
  expect_equal(nrow(edges(knowledge(A, B), expand = TRUE)), 0L)
  expect_type(edges(knowledge(), expand = TRUE)$from, "character")
  # Symmetric statements follow the node order, not the locale.
  expect_equal(edges(knowledge(b, A %!---% b), expand = TRUE)$from, "b")
  # No data.table index leaks into the results or the object.
  bk <- knowledge(A %-->% B, C %!-->% A)
  expect_null(data.table::indices(edges(bk, expand = TRUE)))
})

test_that("knowledge() reports contradictions", {
  expect_error(knowledge(A %-->% B, B %-->% A), class = "caugi_inconsistent")
  expect_error(
    knowledge(A %---% B, A %!---% B),
    "A and B",
    class = "caugi_inconsistent"
  )
  expect_error(knowledge(tier(A, B), B %-->% A), class = "caugi_inconsistent")
  expect_error(
    knowledge(A %-->% B, B %-->% C, C %-->% A),
    "cycle",
    class = "caugi_inconsistent"
  )
  expect_no_error(knowledge(A %-->% B, B %-->% C, A %-->% C))
})

test_that("knowledge() checks its parts", {
  expect_error(
    knowledge(A %-->% D, nodes = c("A", "B")),
    "Unknown node\\(s\\): D"
  )
  expect_error(knowledge(A %-->% A), "itself")
  expect_error(knowledge(tier(A, A + B)), "only one tier")
  expect_error(knowledge(tier(A, B), C %-->% A), "without a tier: C")
  expect_error(knowledge(tier(A, B), tier(C)), "one `tier\\(\\)`")
  for (lag in list(0, 1.5, Inf, "2", c(1, 2), NA)) {
    expect_error(knowledge(tier(A, B, max_lag = lag)), "whole number")
  }
  expect_error(knowledge(tier(max_lag = 1)), "needs tiers")
  expect_error(knowledge(tier(A, `1` = B)), "unique")
  expect_error(knowledge(tier(a = A, a = B)), "unique")
  expect_error(knowledge(D, nodes = c("A", "B")), "Unknown node\\(s\\): D")
  expect_error(knowledge(foo(A)), "Expected an edge")
  expect_error(knowledge(c(A %-->% B)), "Expected an edge")
})
