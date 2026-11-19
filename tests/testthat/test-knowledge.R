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
  expect_error(add_edges(bk, A %-->% D), "Unknown node\\(s\\): D")
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

test_that("edge verbs edit knowledge", {
  bk <- knowledge(A %-->% B) |> add_edges(!(B %-->% C))
  expect_identical(add_edges(bk), bk)
  expect_equal(.rows(bk), c("A B required", "B C forbidden"))
  expect_equal(
    .rows(set_edges(bk, !(A %-->% B))),
    c("A B forbidden", "B C forbidden")
  )
  expect_equal(.rows(remove_edges(bk, !(B %-->% C))), "A B required")
  # With vectors, status defaults to required, or to both kinds for removal.
  expect_equal(
    .rows(add_edges(bk, from = "C", edge = "-->", to = "D")),
    c("A B required", "B C forbidden", "C D required")
  )
  expect_equal(.rows(remove_edges(bk, from = "B", to = "C")), "A B required")
  expect_equal(
    .rows(add_edges(
      bk,
      from = c("C", "D"),
      to = c("E", "E"),
      status = "forbidden"
    )),
    c("A B required", "B C forbidden", "C E forbidden", "D E forbidden")
  )
  expect_error(add_edges(bk, C), "Expected statements, not node\\(s\\): C")
  expect_error(
    add_edges(bk, !(A %-->% D), status = "forbidden"),
    "`status` goes with `from` and `to`"
  )
  expect_error(
    add_edges(bk, from = "A", edge = "---", to = "C"),
    "written with `-->`"
  )
  expect_error(
    add_edges(bk, from = "A", to = "C", status = "maybe"),
    '"required" or "forbidden"'
  )
  expect_error(add_edges(bk, from = c("A", "B"), to = "C"), "equal length")
  expect_error(
    set_edges(caugi(A %-->% B), from = "A", to = "B", status = "required"),
    "made by `knowledge\\(\\)`"
  )
})

test_that("node verbs edit knowledge", {
  bk <- knowledge(A %-->% B)
  expect_equal(nodes(add_nodes(bk, C))$name, c("A", "B", "C"))
  expect_equal(nodes(remove_nodes(bk, A))$name, "B")
})

test_that("set_tiers() and set_exogenous() replace tiers and exogenous nodes", {
  bk <- set_tiers(knowledge(A %-->% B), t1 = A, t2 = B + C, max_lag = 1)
  expect_equal(tiers(bk), list(t1 = "A", t2 = c("B", "C")))
  # max_lag survives new tiers, and goes with max_lag = NULL.
  kept <- set_tiers(bk, tiers = list(early = c("A", "B"), "C"))
  expect_equal(tiers(kept), list(early = c("A", "B"), `2` = "C"))
  expect_identical(rs_kn_tiers(kept@ptr)$max_lag, 1L)
  expect_null(rs_kn_tiers(set_tiers(bk, A, B, max_lag = NULL)@ptr)$max_lag)
  expect_equal(tiers(set_tiers(bk)), list())
  expect_error(set_tiers(bk, A, tiers = list("A")), "not both")

  exo <- function(bk) with(nodes(bk), name[exogenous])
  expect_equal(exo(set_exogenous(bk, A)), "A")
  expect_equal(exo(set_exogenous(bk, name = c("A", "D"))), c("A", "D"))
  expect_error(set_exogenous(caugi(A %-->% B), A), "knowledge")
})
