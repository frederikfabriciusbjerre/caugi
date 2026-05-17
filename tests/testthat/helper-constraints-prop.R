# ──────────────────────────────────────────────────────────────────────────────
# ────── Helpers for property-based tests on the constraint system ─────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# Random generators for graphs and constraints. Property tests use these
# to drive caugi through a wide input space. All random calls live
# behind explicit `set.seed()` per test_that() block so failures are
# reproducible.

#' Pool of node names used throughout the property tests.
.prop_node_pool <- function() c("A", "B", "C", "D", "E")

#' Sample a random constraint-eligible glyph for the given class.
.prop_random_glyph <- function(class) {
  pool <- switch(
    class,
    DAG = "-->",
    UG = "---",
    PDAG = c("-->", "---"),
    ADMG = c("-->", "<->")
  )
  sample(pool, 1L)
}

#' Build an unevaluated edge-atom expression `from %glyph% to`.
.prop_edge_atom_expr <- function(from, to, glyph) {
  op_name <- paste0("%", glyph, "%")
  call(op_name, as.name(from), as.name(to))
}

#' Build a random edge atom over `nodes`, respecting the class's glyphs.
.prop_random_edge_atom <- function(nodes, class) {
  pair <- sample(nodes, 2L, replace = FALSE)
  glyph <- .prop_random_glyph(class)
  .prop_edge_atom_expr(pair[[1L]], pair[[2L]], glyph)
}

#' Random boolean composition of edge atoms. `depth` bounds the nesting
#' so generated expressions don't blow up.
.prop_random_formula_expr <- function(nodes, class, depth = 2L) {
  if (depth <= 0L || runif(1) < 0.35) {
    return(.prop_random_edge_atom(nodes, class))
  }
  op <- sample(c("!", "&", "|"), 1L)
  if (op == "!") {
    return(call("!", .prop_random_formula_expr(nodes, class, depth - 1L)))
  }
  call(
    op,
    .prop_random_formula_expr(nodes, class, depth - 1L),
    .prop_random_formula_expr(nodes, class, depth - 1L)
  )
}

#' Build a `caugi_constraints` from a list of unevaluated expressions
#' without going through NSE at the call site. We splice the
#' expressions into a single `caugi_constraints(...)` call and `eval`
#' it — this side-steps `do.call(..., quote = TRUE)`'s habit of
#' wrapping already-language args in an extra `quote()` call.
.prop_build_constraints <- function(exprs) {
  call_obj <- as.call(c(list(quote(caugi_constraints)), exprs))
  eval(call_obj, envir = parent.frame())
}

#' Build a random DAG over `nodes` by sampling a random topological
#' order and including each forward edge with probability `p`.
.prop_random_dag <- function(nodes, p = 0.5) {
  order <- sample(nodes)
  edges <- data.frame(
    from = character(0L),
    edge = character(0L),
    to = character(0L),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(length(order) - 1L)) {
    for (j in (i + 1L):length(order)) {
      if (runif(1) < p) {
        edges <- rbind(
          edges,
          data.frame(
            from = order[[i]],
            edge = "-->",
            to = order[[j]],
            stringsAsFactors = FALSE
          )
        )
      }
    }
  }
  if (nrow(edges) == 0L) {
    caugi(nodes = nodes, class = "DAG")
  } else {
    caugi(edges_df = edges, nodes = nodes, class = "DAG")
  }
}

#' Brute-force satisfaction count: for every DAG on `nodes` (enumerated
#' via the solver), check whether the evaluator says it satisfies `ctr`.
#' The solver should agree with the resulting count exactly.
.prop_brute_force_count <- function(ctr, nodes) {
  all_dags <- enumerate(caugi_constraints(), nodes, class = "DAG", limit = 1000L)
  ok <- vapply(all_dags, function(cg) satisfies(cg, ctr), logical(1L))
  sum(ok)
}
