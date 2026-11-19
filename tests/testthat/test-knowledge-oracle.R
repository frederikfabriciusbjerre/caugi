# The oracle for the logic is in Rust (src/rust/src/knowledge/oracle.rs). Here,
# random knowledge written with the DSL and built with the verbs must agree.

test_that("knowledge() and the verbs build the same knowledge", {
  set.seed(1)
  nodes <- c("A", "B", "C", "D")
  for (i in 1:200) {
    k <- sample(0:6, 1)
    from <- sample(nodes, k, replace = TRUE)
    to <- vapply(from, function(f) sample(setdiff(nodes, f), 1), "")
    status <- sample(c("required", "forbidden"), k, replace = TRUE)
    tiers <- split(nodes, sample(c("t1", "t2", NA), 4, replace = TRUE))
    exogenous <- nodes[stats::runif(4) < 0.2]

    statement <- function(r) {
      ex <- call("%-->%", as.name(from[r]), as.name(to[r]))
      if (status[r] == "forbidden") call("!", call("(", ex)) else ex
    }
    plus <- function(v) {
      Reduce(function(x, y) call("+", x, y), lapply(v, as.name))
    }
    calls <- c(
      lapply(seq_len(k), statement),
      if (length(tiers)) list(as.call(c(quote(tier), lapply(tiers, plus)))),
      list(as.call(c(quote(exogenous), lapply(exogenous, as.name))))
    )
    edges_of <- function(f) {
      tryCatch(edges(f(), expand = TRUE), caugi_inconsistent = function(e) NULL)
    }
    dsl <- edges_of(function() {
      do.call(knowledge, c(calls, list(nodes = nodes)))
    })
    verbs <- edges_of(function() {
      knowledge(nodes = nodes) |>
        add_edges(from = from, to = to, status = status) |>
        set_exogenous(name = exogenous) |>
        set_tiers(tiers = tiers)
    })
    expect_identical(dsl, verbs, info = paste("case", i))
  }
})
