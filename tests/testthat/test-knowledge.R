# The logic is tested in Rust (src/rust/src/knowledge.rs and its oracle);
# these tests cover the R layer.

.rows <- function(bk) with(edges(bk), paste(from, to, status))

test_that("knowledge() reads statements, node sets and bare nodes", {
  bk <- knowledge(!(A + B %-->% C), D %-->% A %-->% E, exogenous(D, "B"), F)
  expect_equal(nodes(bk)$name, c("F", "D", "B", "A", "E", "C"))
  expect_equal(
    .rows(bk),
    c("A C forbidden", "A E required", "B C forbidden", "D A required")
  )
  expect_equal(nodes(bk)$exogenous, c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(names(edges(bk)), c("from", "edge", "to", "status"))
  expect_equal(nrow(edges(knowledge())), 0L)
})

test_that("knowledge(nodes = ) fixes the nodes", {
  bk <- knowledge(A, "B", nodes = c("A", "B", "C"))
  expect_equal(nodes(bk)$name, c("A", "B", "C"))
  expect_error(knowledge(D, nodes = c("A", "B")), "Unknown node\\(s\\): D")
})

test_that("tier() names tiers and evaluates max_lag", {
  lag <- 2
  bk <- knowledge(tier(A, late = B, C, max_lag = lag), D)
  expect_equal(tiers(bk), list(`1` = "A", late = "B", `3` = "C"))
  expect_identical(rs_kn_tiers(bk@ptr)$max_lag, 2L)
  expect_equal(nodes(bk)$tier, c(NA, "1", "late", "3"))
  expect_equal(tiers(knowledge(A)), list())
  for (lag in list(0, 1.5, Inf, "2", c(1, 2), NA)) {
    expect_error(knowledge(tier(A, B, max_lag = lag)), "whole number")
  }
})

test_that("knowledge() reports bad statements", {
  expect_error(knowledge(!A %-->% B), "Negate a whole statement")
  expect_error(knowledge(!(A)), "Negate statements, not nodes")
  expect_error(knowledge(A %---% B), "written with `%-->%`, not `%---%`")
  expect_error(knowledge(tier(A), tier(B)), "one `tier\\(\\)`")
  expect_error(knowledge(foo(A)), "Expected an edge")
  expect_error(knowledge(A %-->% A), "itself")
  expect_error(knowledge(A %-->% B, B %-->% A), class = "caugi_inconsistent")
  expect_error(
    knowledge(A %-->% B, B %-->% C, C %-->% A),
    "cycle",
    class = "caugi_inconsistent"
  )
})

test_that("is_knowledge() tells knowledge apart", {
  expect_true(is_knowledge(knowledge(A %-->% B)))
  expect_false(is_knowledge(caugi(A %-->% B)))
  expect_error(tiers(caugi(A %-->% B)), "knowledge")
})
