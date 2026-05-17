# ──────────────────────────────────────────────────────────────────────────────
# ───────────── caugi_constraints — property-based tests ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────
#
# Each block:
#   1. seeds the RNG (so failures are reproducible),
#   2. generates a batch of random inputs,
#   3. asserts a property that holds for every input.
#
# The helpers live in `helper-constraints-prop.R` (auto-sourced by
# testthat). Generators draw from a small node pool and bounded
# formula depth so individual iterations stay fast.

# ── P1 — classifier round-trip ──────────────────────────────────────────────
#
# Every random edge atom parses into the expected `edge` AST node
# with matching from / to / etype.

test_that("P1: random edge atoms classify with the expected fields", {
  set.seed(1L)
  for (class in c("DAG", "UG", "PDAG", "ADMG")) {
    nodes <- .prop_node_pool()
    for (i in seq_len(40L)) {
      pair <- sample(nodes, 2L)
      glyph <- .prop_random_glyph(class)
      expr <- .prop_edge_atom_expr(pair[[1L]], pair[[2L]], glyph)
      ctr <- .prop_build_constraints(list(expr))
      expect_length(ctr@formulas, 1L)
      atom <- ctr@formulas[[1L]]$atom
      expect_identical(atom$kind, "edge")
      expect_identical(atom$from, pair[[1L]])
      expect_identical(atom$to, pair[[2L]])
      expect_identical(atom$etype, glyph)
    }
  }
})

# ── P2 — boolean algebra laws on caugi_constraints ─────────────────────────
#
# `&` concatenates formulas; `&` with an empty set is a no-op; `negate`
# wraps once. These are structural laws on the AST list (we deliberately
# don't claim semantic equality — that's left to the solver).

test_that("P2: & between constraint sets is the formula-list concatenation", {
  set.seed(2L)
  for (i in seq_len(50L)) {
    nodes <- .prop_node_pool()
    e1 <- replicate(sample(1:3, 1L), .prop_random_edge_atom(nodes, "DAG"), simplify = FALSE)
    e2 <- replicate(sample(1:3, 1L), .prop_random_edge_atom(nodes, "DAG"), simplify = FALSE)
    ctr1 <- .prop_build_constraints(e1)
    ctr2 <- .prop_build_constraints(e2)
    combined <- ctr1 & ctr2
    expect_length(combined@formulas, length(ctr1@formulas) + length(ctr2@formulas))
  }
})

test_that("P2: empty constraint set is the right identity for &", {
  set.seed(3L)
  empty <- caugi_constraints()
  for (i in seq_len(30L)) {
    exprs <- replicate(sample(1:3, 1L), .prop_random_edge_atom(.prop_node_pool(), "DAG"),
                       simplify = FALSE)
    ctr <- .prop_build_constraints(exprs)
    expect_identical((ctr & empty)@formulas, ctr@formulas)
    expect_identical((empty & ctr)@formulas, ctr@formulas)
  }
})

test_that("P2: negate wraps once; double-negate leaves a Not(Not(...)) structure", {
  set.seed(4L)
  for (i in seq_len(30L)) {
    exprs <- list(.prop_random_edge_atom(.prop_node_pool(), "DAG"))
    ctr <- .prop_build_constraints(exprs)
    once <- caugi:::negate(ctr)
    twice <- caugi:::negate(once)
    expect_length(once@formulas, 1L)
    expect_identical(once@formulas[[1L]]$kind, "not")
    expect_length(twice@formulas, 1L)
    expect_identical(twice@formulas[[1L]]$kind, "not")
    expect_identical(twice@formulas[[1L]]$body$kind, "not")
  }
})

# ── P3 — evaluator-solver duality on small DAGs ─────────────────────────────
#
# For every random constraint set, the number of DAGs the solver
# enumerates as satisfying must equal the number of DAGs that the
# evaluator (independently, on each DAG) reports as satisfying.
# This is the strongest cross-layer agreement check we can do.

test_that("P3: evaluator and solver agree on satisfying-DAG counts", {
  set.seed(5L)
  nodes <- c("A", "B", "C") # 25 DAGs total
  for (i in seq_len(40L)) {
    n_clauses <- sample(1:3, 1L)
    exprs <- replicate(n_clauses, .prop_random_formula_expr(nodes, "DAG", depth = 2L),
                       simplify = FALSE)
    ctr <- .prop_build_constraints(exprs)
    solver_count <- length(enumerate(ctr, nodes, class = "DAG", limit = 100L))
    eval_count <- .prop_brute_force_count(ctr, nodes)
    expect_equal(
      solver_count, eval_count,
      info = paste0(
        "Disagreement on:\n",
        format(ctr)
      )
    )
  }
})

# ── P4 — negation duality at the evaluator level ────────────────────────────
#
# For every DAG and every random constraint set, exactly one of
# `satisfies(cg, ctr)` and `satisfies(cg, !ctr)` is TRUE — UNLESS the
# original ctr is vacuously true (empty), in which case both branches
# trivially hold (And([]) = TRUE, Not(And([])) = FALSE).
#
# `negate(ctr)` wraps the whole conjunction in Not, so the duality is
# `satisfies(cg, ctr) != satisfies(cg, negate(ctr))` for non-empty ctr.

test_that("P4: negate flips the evaluator's verdict", {
  set.seed(6L)
  nodes <- c("A", "B", "C")
  for (i in seq_len(60L)) {
    exprs <- list(.prop_random_formula_expr(nodes, "DAG", depth = 2L))
    ctr <- .prop_build_constraints(exprs)
    cg <- .prop_random_dag(nodes)
    a <- satisfies(cg, ctr)
    b <- satisfies(cg, caugi:::negate(ctr))
    expect_false(isTRUE(a) && isTRUE(b))
    expect_true(isTRUE(a) || isTRUE(b))
  }
})

# ── P5 — quantifier expansion ───────────────────────────────────────────────
#
# `forall(X, body[X])` is equivalent to a conjunction over all current
# nodes; `exists` is the matching disjunction. The evaluator should
# return the same answer either way.

test_that("P5: forall(X, atom(X)) matches its manual conjunction", {
  set.seed(7L)
  nodes <- c("A", "B", "C")
  for (i in seq_len(30L)) {
    target <- sample(nodes, 1L)
    # forall(X, X %-->% target)
    cg <- .prop_random_dag(nodes)
    ctr <- .prop_build_constraints(list(bquote(
      forall(X, X %-->% .(as.name(target)))
    )))
    by_forall <- satisfies(cg, ctr)
    # Manual: every node n has edge n --> target.
    e <- edges(cg)
    by_hand <- all(vapply(
      nodes,
      function(n) any(e$from == n & e$to == target & e$edge == "-->"),
      logical(1L)
    ))
    expect_identical(by_forall, by_hand)
  }
})

test_that("P5: exists(X, atom(X)) matches its manual disjunction", {
  set.seed(8L)
  nodes <- c("A", "B", "C")
  for (i in seq_len(30L)) {
    target <- sample(nodes, 1L)
    cg <- .prop_random_dag(nodes)
    ctr <- .prop_build_constraints(list(bquote(
      exists(X, X %-->% .(as.name(target)))
    )))
    by_exists <- satisfies(cg, ctr)
    e <- edges(cg)
    by_hand <- any(vapply(
      nodes,
      function(n) any(e$from == n & e$to == target & e$edge == "-->"),
      logical(1L)
    ))
    expect_identical(by_exists, by_hand)
  }
})

# ── P6 — cardinality matches the true count ──────────────────────────────────
#
# For every random DAG and every target node, `at_most(k, parents(X))`
# should agree with `length(parents(X)) <= k` on the actual graph.

test_that("P6: at_most(k, parents(X)) matches the true parent count", {
  set.seed(9L)
  nodes <- c("A", "B", "C", "D")
  for (i in seq_len(40L)) {
    target <- sample(nodes, 1L)
    k <- sample(0:3, 1L)
    cg <- .prop_random_dag(nodes, p = 0.5)
    ctr <- .prop_build_constraints(list(bquote(
      at_most(.(k), parents(.(as.name(target))))
    )))
    actual_parents <- length(parents(cg, target))
    by_card <- satisfies(cg, ctr)
    by_count <- actual_parents <= k
    expect_identical(by_card, by_count)
  }
})

test_that("P6: exactly(k, children(X)) matches the true child count", {
  set.seed(10L)
  nodes <- c("A", "B", "C", "D")
  for (i in seq_len(40L)) {
    target <- sample(nodes, 1L)
    k <- sample(0:3, 1L)
    cg <- .prop_random_dag(nodes, p = 0.4)
    ctr <- .prop_build_constraints(list(bquote(
      exactly(.(k), children(.(as.name(target))))
    )))
    by_card <- satisfies(cg, ctr)
    by_count <- length(children(cg, target)) == k
    expect_identical(by_card, by_count)
  }
})

# ── P7 — predicate inlining ─────────────────────────────────────────────────
#
# A predicate invocation should classify to exactly the same AST as the
# literal substituted body.

test_that("P7: predicate inlining matches a manually substituted body", {
  set.seed(11L)
  nodes <- c("A", "B", "C", "D")
  for (i in seq_len(20L)) {
    target <- sample(nodes, 1L)
    bound <- "ZZZ"

    # Predicate: function(X) X %-->% target  — but `target` is captured by
    # name in the body. We construct an equivalent literal body for
    # comparison.
    pred <- caugi_predicate(function(X) X %-->% TARGET)
    # We need the body to refer to `target` (the concrete node). The
    # predicate's body literally contains the symbol `TARGET`. Build the
    # call site by substituting X with a bound name, and compare against
    # `caugi_constraints(bound %-->% TARGET)` then swapping TARGET for
    # `target`. Simpler: directly compare classified ASTs of
    # `pred(bound)` and `bound %-->% TARGET`, after we rename TARGET to
    # `target` in both — they live in the same namespace.

    # Simpler yet: a predicate whose body uses both args, then inline.
    pred2 <- caugi_predicate(function(U, V) U %-->% V)
    via_pred <- .prop_build_constraints(list(bquote(pred2(
      .(as.name(bound)), .(as.name(target))
    ))))
    direct <- .prop_build_constraints(list(bquote(
      .(as.name(bound)) %-->% .(as.name(target))
    )))
    expect_identical(via_pred@formulas, direct@formulas)
  }
})

# ── P8 — enumerate partitions correctly under negation ───────────────────────
#
# For any non-trivial atom, the count of DAGs satisfying ctr plus the
# count satisfying its negation should equal the total number of DAGs
# on the same node set. This is a strong sanity check on both
# encoder and reconstructor.

test_that("P8: enumerate(ctr) and enumerate(!ctr) partition the DAG family", {
  set.seed(12L)
  nodes <- c("A", "B", "C")
  total <- length(enumerate(caugi_constraints(), nodes, class = "DAG", limit = 100L))
  for (i in seq_len(20L)) {
    atom <- .prop_random_edge_atom(nodes, "DAG")
    ctr <- .prop_build_constraints(list(atom))
    ctr_neg <- caugi:::negate(ctr)
    a <- length(enumerate(ctr, nodes, class = "DAG", limit = 100L))
    b <- length(enumerate(ctr_neg, nodes, class = "DAG", limit = 100L))
    expect_equal(a + b, total)
  }
})
