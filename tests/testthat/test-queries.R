# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Queries tests ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────── caugi type check ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("is_caugi works", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_true(is_caugi(cg))

  not_cg <- list(a = 1, b = 2)
  expect_false(is_caugi(not_cg))

  expect_error(is_caugi(not_cg, throw_error = TRUE))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Acyclicity ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────
test_that("acyclicity check works", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% A)

  expect_false(is_acyclic(cg))

  cg <- cg |> set_edges(C %---% A)
  expect_true(is_acyclic(cg))
})

test_that("is_acyclic forces check when requested", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")

  expect_true(is_acyclic(cg))
  expect_true(is_acyclic(cg, force_check = TRUE))
})

test_that("is_acyclic fast path handles MPDAG class", {
  cg <- caugi(
    A %---% B,
    A %-->% C,
    B %-->% C,
    class = "MPDAG"
  )
  expect_true(is_acyclic(cg))
  expect_true(is_acyclic(cg, force_check = TRUE))
})

test_that("is_simple checks the graph structure", {
  cg_simple <- caugi(A %-->% B, class = "DAG")
  expect_true(is_simple(cg_simple))
  expect_true(is_simple(cg_simple, force_check = TRUE))

  cg_nonsimple <- caugi(
    A %-->% B,
    A %<->% B,
    class = "UNKNOWN"
  )
  expect_false(is_simple(cg_nonsimple))
  expect_false(is_simple(cg_nonsimple, force_check = TRUE))

  # UNKNOWN allows multi-edges, but this graph has none
  cg_unknown <- caugi(A %-->% B, class = "UNKNOWN")
  expect_false(cg_unknown@simple)
  expect_true(is_simple(cg_unknown))
  expect_false(is_simple(caugi(A %-->% A, class = "UNKNOWN")))
})

test_that("query builds", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_true(!is.null(cg@session))

  cg <- cg |> add_edges(D %-->% E)
  expect_true(!is.null(cg@session))

  expect_true(is_acyclic(cg))

  # now it should be build
  expect_true(!is.null(cg@session))
})

test_that("build initializes session without querying", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  state_before <- rs_is_valid(cg@session)
  expect_true(state_before$core_valid)
  expect_false(state_before$view_valid)

  expect_invisible(build(cg))

  state_after <- rs_is_valid(cg@session)
  expect_true(state_after$core_valid)
  expect_true(state_after$view_valid)

  # Build should not change graph content
  expect_setequal(nodes(cg)$name, c("A", "B", "C"))
  expect_equal(nrow(edges(cg)), 2L)
})

test_that("build is idempotent and survives updates", {
  cg <- caugi(A %-->% B, class = "DAG")
  build(cg)
  state_built <- rs_is_valid(cg@session)
  expect_true(state_built$core_valid)
  expect_true(state_built$view_valid)

  # idempotent
  build(cg)
  state_built2 <- rs_is_valid(cg@session)
  expect_true(state_built2$core_valid)
  expect_true(state_built2$view_valid)

  # updating invalidates session; build again should restore
  cg <- add_edges(cg, B %-->% C)
  state_after_update <- rs_is_valid(cg@session)
  expect_true(state_after_update$core_valid)
  expect_false(state_after_update$view_valid)

  build(cg)
  state_rebuilt <- rs_is_valid(cg@session)
  expect_true(state_rebuilt$core_valid)
  expect_true(state_rebuilt$view_valid)
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Is it <type>? ─────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("is_dag works", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")
  expect_true(is_dag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_false(is_dag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "PDAG")
  expect_true(is_dag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "Unknown")
  expect_false(is_dag(cg))

  cg <- cg |> set_edges(C %-->% D)
  expect_true(is_dag(cg))
})

test_that("is_pdag works", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_true(is_pdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")
  expect_true(is_pdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "Unknown")
  expect_true(is_pdag(cg))

  cg <- cg |> set_edges(C %o->% D)
  expect_false(is_pdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %o->% D, class = "Unknown")

  expect_false(is_pdag(cg))
})

test_that("is_cpdag rejects non-chordal undirected components (#378)", {
  # B - D - C - E - B is a chordless 4-cycle; A is joined to all of them.
  cg <- caugi(
    A %---% B + C + D + E,
    B %---% D + E,
    C %---% D + E,
    class = "PDAG"
  )
  expect_false(is_cpdag(cg))
  expect_error(
    caugi(A %---% B + C + D + E, B %---% D + E, C %---% D + E, class = "CPDAG"),
    "not a CPDAG"
  )
})

test_that("is_cpdag agrees with igraph::is_chordal on undirected graphs (#378)", {
  skip_if_not_installed("igraph")
  nm <- LETTERS[1:5]
  pairs <- utils::combn(nm, 2)
  for (code in 0:(2^ncol(pairs) - 1)) {
    keep <- as.logical(intToBits(code))[seq_len(ncol(pairs))]
    cg <- caugi(
      from = pairs[1, keep],
      edge = rep("---", sum(keep)),
      to = pairs[2, keep],
      nodes = nm,
      class = "PDAG"
    )
    chordal <- igraph::is_chordal(as_igraph(cg))$chordal
    expect_identical(is_cpdag(cg), chordal, info = paste("code", code))
  }
})

test_that("is_cpdag works", {
  # Triangle with A--B undirected and A->C, B->C directed.
  # Since A and B are adjacent, there's NO v-structure at C.
  # Directed edges are not protected, so NOT a valid CPDAG.
  cg <- caugi(A %-->% C, B %-->% C, A %---% B, class = "PDAG")
  expect_false(is_cpdag(cg))

  # Regression test: A->B, C->B with A--C undirected (triangle).
  # Same reasoning: A and C are adjacent, so no v-structure at B.
  # The directed edges A->B and C->B are not protected.
  cg <- caugi(A %-->% B, C %-->% B, C %---% A, class = "PDAG")
  expect_false(is_cpdag(cg))

  # A pure directed chain is NOT a valid CPDAG (edges not protected)
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, class = "DAG")
  expect_false(is_cpdag(cg))

  # V-structure 0 -> 2 <- 1 IS a valid CPDAG
  cg <- caugi(A %-->% C, B %-->% C, class = "PDAG")
  expect_true(is_cpdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %o->% D, class = "Unknown")
  expect_false(is_cpdag(cg))

  cg <- caugi(A %-->% B, B %-->% C, C %---% D + E %o->% F, class = "Unknown")
  expect_false(is_cpdag(cg))

  cg <- caugi(A %-->% B, class = "PDAG")
  expect_false(is_cpdag(cg))

  cg <- caugi(A, B, class = "PDAG")
  expect_true(is_cpdag(cg))

  cg <- caugi(A %-->% B, A %---% C, class = "PDAG")
  expect_false(is_cpdag(cg))

  cg <- caugi(
    B %---% A,
    B %---% D,
    C %-->% E,
    B %-->% E,
    D %-->% F,
    E %-->% F,
    class = "PDAG"
  )
  expect_true(is_cpdag(cg))
})

test_that("is_mpdag works", {
  cg_closed <- caugi(
    A %-->% C,
    B %-->% C,
    class = "PDAG"
  )
  expect_true(is_mpdag(cg_closed))

  # R1 applies: A -> B, C -> B, B -- D, and C not adjacent to D.
  cg_r1 <- caugi(
    A %-->% B,
    C %-->% B,
    B %---% D,
    A %---% D,
    class = "PDAG"
  )
  expect_false(is_mpdag(cg_r1))

  # R2 applies: A -- B and A -> C -> B.
  cg_r2 <- caugi(
    A %---% B,
    A %-->% C,
    C %-->% B,
    class = "PDAG"
  )
  expect_false(is_mpdag(cg_r2))

  # R3 applies: A -- B, C -> B, D -> B, C !~ D, and A -- C, A -- D.
  cg_r3 <- caugi(
    A %---% B,
    C %-->% B,
    D %-->% B,
    A %---% C,
    A %---% D,
    class = "PDAG"
  )
  expect_false(is_mpdag(cg_r3))

  # R4 applies: A -- B and A => B through A -> C -> D -> B.
  cg_r4 <- caugi(
    A %---% B,
    A %-->% C,
    C %-->% D,
    A %---% D,
    D %-->% B,
    class = "PDAG"
  )
  expect_false(is_mpdag(cg_r4))

  cg_partial <- caugi(A %o->% B, class = "UNKNOWN")
  expect_false(is_mpdag(cg_partial))
})

test_that("is_mpdag tracks causal-learn style multi-rule progression", {
  # Same fixture as the operations regression test:
  # A-B-C, A->D<-C, B-D, D-E, C-E
  g <- caugi(
    A %---% B,
    B %---% C,
    A %-->% D,
    C %-->% D,
    B %---% D,
    D %---% E,
    C %---% E,
    class = "PDAG"
  )

  expect_false(is_mpdag(g))

  g_closed <- meek_closure(g)
  expect_true(is_mpdag(g_closed))

  # Expected closure leaves only chain edges A---B---C undirected.
  und_A <- neighbors(g_closed, "A", mode = "undirected")
  und_B <- neighbors(g_closed, "B", mode = "undirected")
  und_C <- neighbors(g_closed, "C", mode = "undirected")

  expect_setequal(und_A, "B")
  expect_setequal(und_B, c("A", "C"))
  expect_setequal(und_C, "B")
})

test_that("is_pdag fast path handles MPDAG class", {
  cg <- caugi(
    A %---% B,
    A %-->% C,
    B %-->% C,
    class = "MPDAG"
  )
  expect_true(is_pdag(cg))
  expect_true(is_mpdag(cg))
})

test_that("is_cpdag rejects graphs where Meek R1 would fire", {
  # R1: a->b, b--c, a not adj c => b->c
  # If b--c is still undirected when R1 should have oriented it, it's not a CPDAG.

  # a->b with b--c undirected, a not adjacent to c
  cg <- caugi(A %-->% B, B %---% C, class = "PDAG")
  expect_false(is_cpdag(cg))

  # Cascading R1: a->b, b--c, c--d with a not adj c, b not adj d
  cg <- caugi(A %-->% B, B %---% C, C %---% D, class = "PDAG")
  expect_false(is_cpdag(cg))
})

test_that("is_cpdag rejects graphs where Meek R2 would fire", {
  # R2: a--b and ∃ w: a->w->b => a->b
  # a->w->b with a--b undirected
  cg <- caugi(A %---% B, A %-->% C, C %-->% B, class = "PDAG")
  expect_false(is_cpdag(cg))
})

test_that("is_cpdag rejects graphs where Meek R3 would fire", {
  # R3: a--b with c->b, d->b, c not adj d, a--c, a--d => a->b
  cg <- caugi(
    A %---% B,
    C %-->% B,
    D %-->% B,
    A %---% C,
    A %---% D,
    class = "PDAG"
  )
  expect_false(is_cpdag(cg))
})

test_that("is_cpdag rejects graphs where Meek R4 would fire", {
  # R4: a--b and directed path a => b => orient a->b
  # a--b with directed path a->c->d->b
  cg <- caugi(
    A %---% B,
    A %-->% C,
    C %-->% D,
    D %-->% B,
    class = "PDAG"
  )
  expect_false(is_cpdag(cg))
})

test_that("is_cpdag accepts valid CPDAGs from pgmpy test cases", {
  # pgmpy case 3: A->B, D->C with B--C stays undirected (no rule fires)
  # This is a valid CPDAG: B and C have parents from opposite sides,
  # but B and C are adjacent, so no additional orientation is needed.
  # Actually A->B, D->C, B--C: R1 check: A->B, B--C, A adj C? No.
  # So R1 WOULD fire. This means this is NOT a valid CPDAG.
  # pgmpy represents it differently. Let me use properly valid CPDAGs.

  # V-structure A->C<-B is a valid CPDAG
  cg <- caugi(A %-->% C, B %-->% C, class = "PDAG")
  expect_true(is_cpdag(cg))

  # V-structure with R1 result: A->C<-B, C->D is valid
  cg <- caugi(A %-->% C, B %-->% C, C %-->% D, class = "PDAG")
  expect_true(is_cpdag(cg))

  # Fully undirected triangle (complete graph, no v-structures)
  cg <- caugi(A %---% B, B %---% C, A %---% C, class = "PDAG")
  expect_true(is_cpdag(cg))

  # Single undirected edge
  cg <- caugi(A %---% B, class = "PDAG")
  expect_true(is_cpdag(cg))

  # Undirected chain
  cg <- caugi(A %---% B, B %---% C, class = "PDAG")
  expect_true(is_cpdag(cg))

  # V-structure + R1 cascade + undirected component:
  # B--A, B--D, C->E<-B, D->F<-E
  cg <- caugi(
    B %---% A,
    B %---% D,
    C %-->% E,
    B %-->% E,
    D %-->% F,
    E %-->% F,
    class = "PDAG"
  )
  expect_true(is_cpdag(cg))
})

test_that("is_cpdag accepts graphs with isolated nodes", {
  cg <- caugi(A %-->% C, B %-->% C, D, E, class = "PDAG")
  expect_true(is_cpdag(cg))

  cg <- caugi(A, B, C, class = "PDAG")
  expect_true(is_cpdag(cg))
})

test_that("is_cpdag: pcalg addBgKnowledge-style chain test", {
  # pcalg example: 3-node undirected chain a--b--c
  # This is a valid CPDAG (no v-structures, Markov equivalent to a->b->c etc.)
  cg <- caugi(A %---% B, B %---% C, class = "PDAG")
  expect_true(is_cpdag(cg))

  # After orienting b->c, Meek R1 should orient b->a too.
  # So b->c with a--b (a not adj c) is NOT a valid CPDAG (R1 would fire).
  cg <- caugi(A %---% B, B %-->% C, class = "PDAG")
  expect_false(is_cpdag(cg))

  # Fully oriented b->a, b->c IS a valid CPDAG (a<-b->c v-structure,
  # but a and c are non-adjacent so it's a valid v-structure CPDAG).
  # Wait: a<-b->c with a not adj c: is b a collider? No, b is a parent of both.
  # It's a "fork" not a collider. The directed edges are not protected.
  # Actually in b->a, b->c: these are only protected if there's a v-structure.
  # b->a is protected if ∃ v-structure witness. There's none. So NOT a CPDAG.
  cg <- caugi(B %-->% A, B %-->% C, class = "PDAG")
  expect_false(is_cpdag(cg))
})

test_that("to_cpdag via generate_graph produces valid CPDAGs", {
  # Exhaustive check: generate random DAGs and verify CPDAGs
  for (i in 1:20) {
    cpdag <- generate_graph(n = 8, m = sample(5:12, 1), class = "CPDAG")
    expect_true(is_cpdag(cpdag))
  }
})

test_that("same_nodes works", {
  cg1 <- caugi(A %-->% B, B %-->% C, class = "DAG")
  cg2 <- caugi(B %-->% C, A %-->% B, class = "DAG")
  cg3 <- caugi(A %-->% B, C %-->% D, class = "DAG")

  expect_true(same_nodes(cg1, cg2))
  expect_false(same_nodes(cg1, cg3))
  expect_error(same_nodes(cg1, cg3, throw_error = TRUE))
})

test_that("is_ug works", {
  cg <- caugi(A %---% B, B %---% C, C %---% D, class = "UG")
  expect_true(is_ug(cg))
  expect_true(is_ug(cg, force_check = TRUE))

  cg <- caugi(A %-->% B, B %---% C, C %---% D, class = "PDAG")
  expect_false(is_ug(cg))

  cg <- caugi(A %---% B, B %---% C, C %o->% D, class = "Unknown")
  expect_false(is_ug(cg))
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Getter queries ────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("parents returns expected nodes for names, indices, and expr", {
  cg <- caugi(A %-->% B, B %-->% C, A %---% D, D %-->% B, class = "PDAG")
  expect_identical(parents(cg, "B"), c("A", "D"))
  expect_identical(parents(cg, "B"), c("A", "D"))
  expect_warning(
    pa_AB <- parents(cg, c("A", "B")),
    "several nodes is deprecated"
  )
  expect_null(pa_AB[["A"]])
  expect_setequal(pa_AB[["B"]], c("A", "D"))
  expect_warning(
    pa_2 <- parents(cg, index = 2),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(pa_2, c("A", "D"))
  expect_warning(
    pa_BC <- parents(cg, c("B", "C")),
    "several nodes is deprecated"
  )
  expect_setequal(pa_BC[["B"]], c("A", "D"))
  expect_setequal(pa_BC[["C"]], "B")
})

test_that("children returns expected nodes", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, D %-->% E, class = "PDAG")
  expect_identical(children(cg, "A")[[1]], "B")
  expect_warning(
    ch_BD <- children(cg, c("B", "D")),
    "several nodes is deprecated"
  )
  expect_identical(ch_BD[[1]], "C")
  expect_warning(
    ch_CD <- children(cg, c("C", "D")),
    "several nodes is deprecated"
  )
  expect_identical(ch_CD[[2]], "E")
  # indices (deprecated)
  expect_warning(
    ch_1 <- children(cg, index = 1),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(ch_1[[1]], "B")
})

test_that("neighbors returns undirected and directed adjacency", {
  cg <- caugi(A %-->% B, B %-->% C, B %---% D, C %---% E, class = "PDAG")
  # B has neighbors A (incoming), C (outgoing), D (undirected)
  expect_setequal(neighbors(cg, "B"), c("A", "C", "D"))
  # C has neighbors B and E
  expect_setequal(neighbors(cg, "C"), c("B", "E"))
})

test_that("queries match with nodes and indexes", {
  cg <- caugi(A %-->% B, B %-->% C, B %---% D, C %---% E, class = "PDAG")
  expect_warning(
    {
      expect_identical(children(cg, "A"), children(cg, index = 1))
      expect_identical(parents(cg, "B"), parents(cg, index = 2))
      expect_identical(neighbors(cg, "C"), neighbors(cg, index = 3))
    },
    "`index` argument is deprecated",
    fixed = TRUE
  )
})

test_that("queries fail with bad input", {
  cg <- caugi(A %-->% B, B %-->% C, B %---% D, C %---% E, class = "PDAG")
  expect_error(children(cg, "A", index = 1), "Supply either `nodes` or `index`")
  expect_error(children(cg), "Must supply either `nodes` or `index`.")
  expect_error(parents(cg, "A", index = 1), "Supply either `nodes` or `index`")
  expect_error(parents(cg), "Must supply either `nodes` or `index`.")
  expect_error(
    neighbors(cg, "A", index = 1),
    "Supply either `nodes` or `index`"
  )
  expect_error(neighbors(cg), "Must supply either `nodes` or `index`.")
  expect_error(ancestors(cg, "Z"), "Non-existent node name: Z")
  expect_error(
    ancestors(cg, "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
  expect_error(
    ancestors(cg),
    "Must supply either `nodes` or `index`."
  )
  expect_error(descendants(cg, index = 0), "must be >= 0")
  expect_error(
    descendants(cg, "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
  expect_error(
    descendants(cg),
    "Must supply either `nodes` or `index`."
  )
})

test_that("getter queries handle missing relations and duplicates", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  # node with no parents
  expect_identical(length(parents(cg, "A")[[1]]), 0L)
  # node with no children
  expect_identical(length(children(cg, "C")[[1]]), 0L)
  # duplicate targets collapse to the same combined set
  expect_warning(res <- parents(cg, c("B", "B")), "several nodes is deprecated")
  expect_identical(sort(res[[1]]), sort(parents(cg, "B")[[1]]))
})

test_that("getter queries error on bad nodes or indices", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_error(parents(cg, "Z"), "Non-existent node name: Z")
  expect_error(children(cg, index = 0), "must be >= 0")
  expect_error(children(cg, index = 100), "out of bounds")
})

test_that("aliases route correctly", {
  cg <- caugi(A %-->% B, B %---% C, class = "PDAG")
  expect_identical(neighbours(cg, "B")[[1]], neighbors(cg, "B")[[1]])
})

test_that("public getters trigger lazy build", {
  cg <- caugi(A %-->% B, B %-->% C, class = "PDAG")
  cg <- cg |> add_edges(C %---% D)
  expect_true(!is.null(cg@session))
  parents(cg, "B")
  expect_true(!is.null(cg@session))
})

test_that("nodes and edges getters work", {
  cg <- caugi(A %-->% B, B %-->% C, class = "PDAG")
  nodes_out <- cg@nodes
  edges_out <- cg@edges

  expect_identical(nodes_out, nodes(cg))
  expect_identical(edges_out, edges(cg))

  expect_identical(nodes_out, vertices(cg))
  expect_identical(nodes_out, V(cg))

  expect_identical(edges_out, E(cg))

  expect_equal(nrow(nodes(cg)), 3L)
  expect_equal(nrow(edges(cg)), 2L)

  cg <- caugi()

  expect_equal(nrow(nodes(cg)), 0L)
  expect_equal(nrow(edges(cg)), 0L)
})

test_that("an and de works", {
  cg <- caugi(A %-->% B, B %-->% C, C %---% D, class = "PDAG")
  expect_identical(ancestors(cg, "C"), c("A", "B"))
  expect_identical(descendants(cg, "A"), c("B", "C"))
  expect_warning(
    an_CD <- ancestors(cg, c("C", "D")),
    "several nodes is deprecated"
  )
  expect_identical(sort(an_CD[[1]]), c("A", "B"))
  expect_warning(
    de_AD <- descendants(cg, c("A", "D")),
    "several nodes is deprecated"
  )
  expect_identical(sort(de_AD[[1]]), c("B", "C"))

  # test index (deprecated)
  expect_warning(
    an_3 <- ancestors(cg, index = 3),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(an_3, c("A", "B"))
  expect_warning(
    de_1 <- descendants(cg, index = 1),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(de_1, c("B", "C"))
  expect_warning(
    an_34 <- ancestors(cg, index = c(3, 4)),
    "several nodes is deprecated"
  )
  expect_identical(sort(an_34[[1]]), c("A", "B"))
  expect_warning(
    de_14 <- descendants(cg, index = c(1, 4)),
    "several nodes is deprecated"
  )
  expect_identical(sort(de_14[[1]]), c("B", "C"))

  cg <- caugi(A, B, class = "DAG")

  expect_equal(length(ancestors(cg, "A")), 0L)
  expect_equal(length(descendants(cg, "A")), 0L)
})

test_that("markov_blanket works on DAGs (parents, children, spouses)", {
  cg <- caugi(
    A %-->% B + C,
    D %-->% B,
    B %-->% E,
    F %-->% E,
    class = "DAG"
  )

  mb_A <- markov_blanket(cg, "A")
  expect_setequal(mb_A, c("B", "C", "D"))

  mb_B <- markov_blanket(cg, "B")
  expect_setequal(mb_B, c("A", "D", "E", "F"))

  # unquoted and vector inputs
  expect_warning(
    mb_AC <- markov_blanket(cg, c("A", "C")),
    "several nodes is deprecated"
  )
  expect_setequal(mb_AC[[1]], c("B", "C", "D"))
  expect_setequal(mb_AC[[2]], c("A"))

  # index input (deprecated)
  expect_warning(
    mb_idx <- markov_blanket(cg, index = 1),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_setequal(mb_idx, c("B", "C", "D"))
})

test_that("markov_blanket on ADMGs and AGs follows collider paths (#384)", {
  # Children are in the blanket, whatever the class label.
  expect_equal(
    markov_blanket(caugi(A %-->% B, B %-->% C, class = "ADMG"), "A"),
    "B"
  )
  expect_setequal(
    markov_blanket(caugi(A %-->% B, B %-->% C, class = "ADMG"), "B"),
    c("A", "C")
  )
  # S is reached through the collider path N -> R <-> S.
  ag <- caugi(A %-->% R + S, N %-->% R, R %<->% S, class = "AG")
  mb <- markov_blanket(ag, "N")
  expect_setequal(mb, c("A", "R", "S"))
})

test_that("markov_blanket on ADMGs matches brute-force m-separation (#384)", {
  # The Markov boundary of v is {w : v and w are m-connected given all other nodes}.
  oracle <- function(cg, v) {
    V <- nodes(cg)$name
    Filter(
      function(w) !m_separated(cg, v, w, Z = setdiff(V, c(v, w))),
      setdiff(V, v)
    )
  }
  set.seed(384)
  for (k in 1:30) {
    nm <- LETTERS[1:5]
    ord <- sample(nm)
    pairs <- utils::combn(5, 2)
    type <- sample(
      c("", "-->", "<->"),
      ncol(pairs),
      replace = TRUE,
      prob = c(0.4, 0.35, 0.25)
    )
    keep <- type != ""
    cg <- caugi(
      from = ord[pairs[1, keep]],
      edge = type[keep],
      to = ord[pairs[2, keep]],
      nodes = nm,
      class = "ADMG"
    )
    for (v in nm) {
      expect_identical(
        sort(as.character(markov_blanket(cg, v))),
        sort(oracle(cg, v))
      )
    }
  }
})

test_that("markov_blanket includes undirected neighbors in PDAGs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    D %-->% B,
    class = "PDAG"
  )
  mb_B <- markov_blanket(cg, "B")
  expect_setequal(mb_B, c("A", "C", "D"))
})

test_that("markov_blanket matches a multi-parent fixture on DAGs", {
  cg <- caugi(
    W %-->% Y,
    X %-->% W,
    Z1 %-->% X + Z3,
    Z2 %-->% Y + Z3,
    Z3 %-->% X + Y,
    class = "DAG"
  )

  expect_setequal(markov_blanket(cg, "Z1"), c("X", "Z2", "Z3"))
  expect_setequal(markov_blanket(cg, "Y"), c("W", "Z2", "Z3"))
})

test_that("markov_blanket argument validation", {
  cg <- caugi(A %-->% B)
  expect_error(
    markov_blanket(cg),
    "Must supply either `nodes` or `index`."
  )
  expect_error(
    markov_blanket(cg, nodes = "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
})

test_that("exogenous works", {
  cg <- caugi(
    A %-->% B + C,
    D %-->% B,
    B %-->% E,
    F %-->% E,
    class = "DAG"
  )

  e <- exogenous(cg)
  expect_setequal(e, c("A", "D", "F"))

  cg <- caugi(A %---% B, C %-->% A, class = "PDAG")
  e <- exogenous(cg)
  expect_setequal(e, c("B", "C"))

  expect_error(exogenous("not a graph"), "Input must be a caugi")
})

test_that("exogenous works on PDAGs", {
  cg <- caugi(A %---% B, C %-->% D, class = "PDAG")
  e <- exogenous(cg)
  expect_setequal(e, c("A", "B", "C"))

  e <- exogenous(cg, undirected_as_parents = TRUE)
  expect_setequal(e, c("C"))
})

test_that("getter queries errors on non-character input", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_error(parents(cg, 1), "must be a character vector")
  expect_error(children(cg, 2), "must be a character vector")
  expect_error(neighbors(cg, 3), "must be a character vector")
  expect_error(ancestors(cg, 4), "must be a character vector")
  expect_error(descendants(cg, 5), "must be a character vector")
  expect_error(markov_blanket(cg, 6), "must be a character vector")
})

test_that("getter queries builds", {
  getter_queries <- c(
    parents,
    children,
    neighbors,
    ancestors,
    descendants,
    markov_blanket
  )
  for (getter in getter_queries) {
    cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
    getter(cg, "B")
    expect_true(!is.null(cg@session))
  }
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Subgraph ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("subgraph selects nodes and errors with none", {
  cg <- caugi()
  cg <- add_nodes(cg, name = c("A", "B", "C"))
  cg <- add_edges(
    cg,
    from = c("A", "B"),
    edge = c("-->", "-->"),
    to = c("B", "C")
  )
  expect_error(subgraph(cg), "Must supply either `nodes` or `index`.")

  sg <- subgraph(cg, nodes = c("A", "B"))
  expect_setequal(sg@nodes$name, c("A", "B"))
  expect_equal(
    sg@edges,
    data.table::data.table(from = "A", edge = "-->", to = "B")
  )
})

test_that("subgraph with an empty character vector gives an empty graph", {
  sg <- subgraph(caugi(A %-->% B, class = "DAG"), character(0))
  expect_equal(length(sg), 0L)
})

test_that("subgraph re-checks the CPDAG class (#382)", {
  # A single A -> C is not a CPDAG (the arrow is not protected) but is an MPDAG.
  for (built in c(FALSE, TRUE)) {
    cg <- caugi(A %-->% C, B %-->% C, class = "CPDAG")
    if (built) {
      build(cg)
    }
    s <- subgraph(cg, c("A", "C"))
    expect_equal(s@graph_class, "MPDAG")
    expect_equal(parents(s, "C"), "A")
  }
  # A v-structure survives intact.
  cg <- caugi(A %-->% C, B %-->% C, D %---% E, class = "CPDAG")
  expect_equal(subgraph(cg, c("A", "B", "C"))@graph_class, "CPDAG")
})

test_that("subgraph errors on invalid arg combos", {
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B"),
    class = "UNKNOWN"
  )
  expect_error(subgraph(g), "Must supply either `nodes` or `index`.")
  expect_error(subgraph(g, nodes = "A", index = 1), "not both")
})

test_that("subgraph validates index", {
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B"),
    class = "UNKNOWN"
  )
  expect_error(subgraph(g, index = "a"), "`index` must be numeric")
  expect_error(
    subgraph(g, index = c(1, NA_integer_)),
    "`index` cannot contain NA values"
  )
  expect_error(subgraph(g, index = 0), "out of range")
  expect_error(subgraph(g, index = 3), "out of range")
})

test_that("subgraph validates nodes", {
  skip_if_not_installed("data.table")
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B"),
    class = "UNKNOWN"
  )
  expect_error(subgraph(g, nodes = 1), "character vector")
  expect_error(
    subgraph(g, nodes = c("A", NA_character_)),
    "`nodes` cannot contain NA values"
  )
  expect_error(subgraph(g, nodes = c("A", "Z")), "Unknown node\\(s\\): Z")
})

test_that("subgraph catches duplicates (nodes and index)", {
  g <- caugi(
    from = c("A", "B"),
    edge = c("-->", "-->"),
    to = c("C", "D"),
    nodes = c("A", "B", "C", "D"),
    class = "DAG"
  )
  expect_error(subgraph(g, nodes = c("A", "A")), "contains duplicates")
  expect_error(subgraph(g, index = c(1L, 1L)), "contains duplicates")
})

test_that("subgraph on graph without edges keeps nodes and empty edges", {
  g <- caugi(
    from = character(),
    edge = character(),
    to = character(),
    nodes = c("A", "B", "C"),
    class = "UNKNOWN"
  )
  s <- subgraph(g, nodes = c("C", "A"))
  expect_identical(s@nodes$name, c("C", "A"))
  expect_equal(nrow(s@edges), 0L)
  expect_true(!is.null(s@session))
  expect_identical(s@graph_class, g@graph_class)
  expect_identical(s@simple, g@simple)
})

test_that("subgraph filters edges to kept names and sorts", {
  g <- caugi(
    from = c("A", "B", "C", "A"),
    edge = c("-->", "-->", "---", "<->"),
    to = c("B", "C", "A", "C"),
    nodes = c("A", "B", "C", "D"),
    class = "UNKNOWN"
  )
  # Keep C, A => should keep (A <-> C) and (C --- A), sorted by from,to,edge
  s <- subgraph(g, nodes = c("C", "A"))
  expect_identical(s@nodes$name, c("C", "A"))
  expect_equal(nrow(s@edges), 2L)
  expect_identical(s@edges$from, c("A", "C"))
  expect_identical(s@edges$to, c("C", "A"))
  expect_identical(s@edges$edge, c("<->", "---"))
})

test_that("subgraph with index matches nodes variant", {
  g <- caugi(
    from = c("A", "B", "C", "A"),
    edge = c("-->", "-->", "---", "-->"),
    to = c("D", "E", "G", "F"),
    nodes = c("A", "B", "C", "D", "E", "F", "G"),
    class = "PDAG"
  )
  s1 <- subgraph(g, nodes = c("B", "A", "C"))
  expect_warning(
    s2 <- subgraph(g, index = c(2L, 1L, 3L)),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(s1@nodes$name, s2@nodes$name)
  expect_identical(s1@edges, s2@edges)
  expect_true(!is.null(s1@session) && !is.null(s2@session))
})

test_that("districts supports all, nodes, and index modes", {
  cg <- caugi(
    A %<->% B,
    B %<->% C,
    C %-->% D,
    class = "ADMG"
  )

  all_d <- districts(cg)
  expect_equal(length(all_d), 2L)
  expect_true(any(vapply(
    all_d,
    function(x) setequal(x, c("A", "B", "C")),
    logical(1)
  )))
  expect_true(any(vapply(all_d, function(x) identical(x, "D"), logical(1))))

  expect_setequal(districts(cg, nodes = "A"), c("A", "B", "C"))

  expect_warning(
    by_nodes <- districts(cg, nodes = c("A", "D")),
    "several nodes is deprecated"
  )
  expect_named(by_nodes, c("A", "D"))
  expect_setequal(by_nodes$A, c("A", "B", "C"))
  expect_identical(by_nodes$D, "D")

  expect_warning(
    by_index <- districts(cg, index = c(1L, 4L)),
    "several nodes is deprecated"
  )
  expect_named(by_index, c("A", "D"))
  expect_setequal(by_index$A, c("A", "B", "C"))
  expect_identical(by_index$D, "D")
})

test_that("districts validates argument combinations", {
  cg <- caugi(A %<->% B, class = "ADMG")

  expect_error(
    districts(cg, nodes = "A", index = 1L),
    "either `nodes` or `index`"
  )
  expect_error(districts(cg, index = 0), "out of range")
  expect_error(districts(cg, nodes = c("A", NA_character_)), "without NA")
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────────────── UNKNOWN graph neighbor queries ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("neighbors mode 'all' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %<->% D,
    class = "UNKNOWN"
  )

  # All neighbors
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))
  expect_setequal(neighbors(cg, "C", mode = "all"), c("B", "D"))
})

test_that("neighbors mode 'in' and 'out' work for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "UNKNOWN"
  )

  # In mode (parents)
  expect_null(neighbors(cg, "A", mode = "in"))
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_identical(neighbors(cg, "C", mode = "in"), "B")

  # Out mode (children)
  expect_identical(neighbors(cg, "A", mode = "out"), "B")
  expect_identical(neighbors(cg, "B", mode = "out"), "C")
  expect_null(neighbors(cg, "C", mode = "out"))
})

test_that("neighbors mode 'undirected' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %---% D,
    class = "UNKNOWN"
  )

  # Undirected mode (--- only, not <->)
  expect_null(neighbors(cg, "A", mode = "undirected"))
  expect_identical(neighbors(cg, "B", mode = "undirected"), "C")
  expect_setequal(neighbors(cg, "C", mode = "undirected"), c("B", "D"))
  expect_identical(neighbors(cg, "D", mode = "undirected"), "C")
})

test_that("neighbors mode 'bidirected' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    C %<->% D,
    class = "UNKNOWN"
  )

  # Bidirected mode (<-> only)
  expect_null(neighbors(cg, "A", mode = "bidirected"))
  expect_identical(neighbors(cg, "B", mode = "bidirected"), "C")
  expect_setequal(neighbors(cg, "C", mode = "bidirected"), c("B", "D"))
  expect_identical(neighbors(cg, "D", mode = "bidirected"), "C")
})

test_that("neighbors mode 'partial' works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %o->% C,
    C %o-o% D,
    D %--o% E,
    class = "UNKNOWN"
  )

  # Partial mode returns neighbors where the CURRENT node has a Circle mark.
  # Edge marks:
  # A --> B: A has Tail, B has Arrow
  # B o-> C: B has Circle, C has Arrow
  # C o-o D: both have Circle
  # D --o E: D has Tail, E has Circle (head position has Circle)

  expect_null(neighbors(cg, "A", mode = "partial")) # A has Tail (no Circle)
  expect_identical(neighbors(cg, "B", mode = "partial"), "C") # B has Circle in B o-> C
  expect_identical(neighbors(cg, "C", mode = "partial"), "D") # C has Circle in C o-o D (but Arrow in B o-> C)
  expect_identical(neighbors(cg, "D", mode = "partial"), "C") # D has Circle in C o-o D (but Tail in D --o E)
  expect_identical(neighbors(cg, "E", mode = "partial"), "D") # E has Circle in D --o E
})

test_that("parents and children error for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    B %---% D,
    class = "UNKNOWN"
  )

  # parents, children, and spouses should error for UNKNOWN graphs
  # because only the structural neighbors() query should work
  expect_error(parents(cg, "B"), "not defined for UNKNOWN")
  expect_error(children(cg, "A"), "not defined for UNKNOWN")
  expect_error(spouses(cg, "A"), "not defined for UNKNOWN")

  # Use neighbors() with explicit mode instead
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_identical(neighbors(cg, "A", mode = "out"), "B")
})

test_that("neighbors mode with index works for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "UNKNOWN"
  )

  # Using index parameter (deprecated)
  expect_warning(
    nb_in <- neighbors(cg, index = 2, mode = "in"),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(nb_in, "A")
  expect_warning(
    nb_out <- neighbors(cg, index = 2, mode = "out"),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_identical(nb_out, "C")
})

test_that("neighbors mode works with multiple nodes for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    class = "UNKNOWN"
  )

  expect_warning(
    result <- neighbors(cg, c("B", "C"), mode = "in"),
    "several nodes is deprecated"
  )
  expect_identical(names(result), c("B", "C"))
  expect_identical(result$B, "A")
  expect_identical(result$C, "B")
})

test_that("neighbors mode 'all' is default for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    class = "UNKNOWN"
  )

  # Default should be "all"
  expect_identical(
    neighbors(cg, "B"),
    neighbors(cg, "B", mode = "all")
  )
})

test_that("neighbors mode validation for DAG", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  # Valid modes for DAG: in, out, all
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_identical(neighbors(cg, "B", mode = "out"), "C")
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for DAG: undirected, bidirected, partial
  expect_error(neighbors(cg, "B", mode = "undirected"), "not valid for DAG")
  expect_error(neighbors(cg, "B", mode = "bidirected"), "not valid for DAG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for DAG")
})

test_that("neighbors mode validation for PDAG", {
  cg <- caugi(
    A %-->% B,
    B %---% C,
    class = "PDAG"
  )

  # Valid modes for PDAG: in, out, undirected, all
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_null(neighbors(cg, "B", mode = "out"))
  expect_identical(neighbors(cg, "B", mode = "undirected"), "C")
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for PDAG: bidirected, partial
  expect_error(neighbors(cg, "B", mode = "bidirected"), "not valid for PDAG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for PDAG")
})

test_that("neighbors mode validation for UG", {
  cg <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )

  # Valid modes for UG: undirected, all
  expect_setequal(neighbors(cg, "B", mode = "undirected"), c("A", "C"))
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for UG: in, out, bidirected, partial
  expect_error(neighbors(cg, "B", mode = "in"), "not defined for UG")
  expect_error(neighbors(cg, "B", mode = "out"), "not defined for UG")
  expect_error(neighbors(cg, "B", mode = "bidirected"), "not valid for UG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for UG")
})

test_that("neighbors mode validation for ADMG", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    class = "ADMG"
  )

  # Valid modes for ADMG: in, out, bidirected (spouses), all
  expect_identical(neighbors(cg, "B", mode = "in"), "A")
  expect_null(neighbors(cg, "B", mode = "out"))
  expect_identical(neighbors(cg, "B", mode = "bidirected"), "C")
  expect_setequal(neighbors(cg, "B", mode = "all"), c("A", "C"))

  # Invalid modes for ADMG: undirected, partial
  expect_error(neighbors(cg, "B", mode = "undirected"), "not valid for ADMG")
  expect_error(neighbors(cg, "B", mode = "partial"), "not valid for ADMG")
})

test_that("spouses errors for UNKNOWN graphs", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    C %---% D,
    class = "UNKNOWN"
  )

  # spouses should error for UNKNOWN graphs
  expect_error(spouses(cg, "B"), "not defined for UNKNOWN")

  # Use neighbors with mode = "bidirected" instead
  expect_identical(neighbors(cg, "B", mode = "bidirected"), "C")
  expect_identical(neighbors(cg, "C", mode = "bidirected"), "B")
  expect_null(neighbors(cg, "A", mode = "bidirected"))
  expect_null(neighbors(cg, "D", mode = "bidirected"))
})

test_that("spouses works for ADMG graphs", {
  cg <- caugi(
    A %-->% B,
    B %<->% C,
    class = "ADMG"
  )

  # spouses returns bidirected neighbors (same as neighbors mode="bidirected")
  expect_null(spouses(cg, "A"))
  expect_identical(spouses(cg, "B"), "C")
  expect_identical(spouses(cg, "C"), "B")

  # spouses is equivalent to neighbors with mode = "bidirected"
  expect_identical(spouses(cg, "B"), neighbors(cg, "B", mode = "bidirected"))
})

test_that("spouses errors for graph types without bidirected edges", {
  cg_dag <- caugi(A %-->% B, class = "DAG")
  cg_pdag <- caugi(A %-->% B, B %---% C, class = "PDAG")
  cg_ug <- caugi(A %---% B, class = "UG")

  expect_error(spouses(cg_dag, "A"), "not valid for DAG")
  expect_error(spouses(cg_pdag, "A"), "not valid for PDAG")
  expect_error(spouses(cg_ug, "A"), "not valid for UG")
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Anteriors tests ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("anteriors works for DAG (equals ancestors)", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_null(anteriors(cg, "A"))
  expect_equal(anteriors(cg, "B"), "A")
  expect_equal(sort(anteriors(cg, "C")), c("A", "B"))
})

test_that("anteriors works for PDAG with mixed edges", {
  # PDAG: A -> B --- C, B -> D
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  # A has no anteriors
  expect_null(anteriors(cg, "A"))
  # B's anteriors: A (parent) and C (undirected)
  expect_equal(sort(anteriors(cg, "B")), c("A", "C"))
  # C's anteriors: B (undirected) -> A (parent of B)
  expect_equal(sort(anteriors(cg, "C")), c("A", "B"))
  # D's anteriors: B (parent) -> A (parent of B), C (undirected of B)
  expect_equal(sort(anteriors(cg, "D")), c("A", "B", "C"))
})

test_that("anteriors works for PDAG with undirected cycle", {
  # PDAG: A --- B --- C --- A (triangle)
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "PDAG"
  )
  # All nodes can reach all others via undirected edges
  expect_equal(sort(anteriors(cg, "A")), c("B", "C"))
  expect_equal(sort(anteriors(cg, "B")), c("A", "C"))
  expect_equal(sort(anteriors(cg, "C")), c("A", "B"))
})

test_that("anteriors and posteriors on a UG are the connected component (#383)", {
  cg <- caugi(A %---% B, B %---% C, D, class = "UG")
  expect_setequal(anteriors(cg, "B"), c("A", "C"))
  expect_setequal(posteriors(cg, "A"), c("B", "C"))
  expect_length(anteriors(cg, "D"), 0L)
})

test_that("anteriors and posteriors on an ADMG skip <-> (#383)", {
  cg <- caugi(A %-->% B, B %-->% C, A %<->% D, class = "ADMG")
  expect_setequal(anteriors(cg, "C"), c("A", "B"))
  expect_setequal(posteriors(cg, "A"), c("B", "C"))
  expect_length(anteriors(cg, "D"), 0L)
})

test_that("ancestral queries on UNKNOWN work from the edge classes (#383)", {
  cg <- caugi(A %-->% B, B %---% C, C %<->% D, class = "UNKNOWN")
  expect_equal(ancestors(cg, "B"), "A")
  expect_setequal(anteriors(cg, "C"), c("A", "B"))
  expect_setequal(posteriors(cg, "A"), c("B", "C"))
  expect_error(
    ancestors(caugi(A %o->% B, class = "UNKNOWN"), "B"),
    "partially directed"
  )
})

test_that("anteriors and posteriors follow custom undirected edges (#383)", {
  reset_caugi_registry()
  on.exit(reset_caugi_registry())
  register_caugi_edge("x-x", "other", "other", "undirected", TRUE)

  ug <- caugi(A %---% B, B %x-x% C, D, class = "UG")
  expect_setequal(anteriors(ug, "A"), c("B", "C"))
  expect_setequal(posteriors(ug, "C"), c("A", "B"))
  expect_length(anteriors(ug, "D"), 0L)

  raw <- caugi(A %-->% B, B %x-x% C, class = "UNKNOWN")
  expect_setequal(anteriors(raw, "C"), c("A", "B"))
  expect_setequal(posteriors(raw, "A"), c("B", "C"))
})

test_that("m_separated on a UG is graph separation", {
  ug <- caugi(A %---% B, B %---% C, D, class = "UG")
  expect_false(m_separated(ug, "A", "C"))
  expect_true(m_separated(ug, "A", "C", "B"))
  expect_true(m_separated(ug, "A", "D"))
})

test_that("condition_marginalize works on ADMG and UG input (#383)", {
  adm <- caugi(A %-->% B, B %-->% C, class = "ADMG")
  expect_equal(
    edges(condition_marginalize(adm, marg_vars = "B")),
    edges(caugi(A %-->% C))
  )
  ug <- caugi(A %---% B, B %---% C, class = "UG")
  expect_equal(
    edges(condition_marginalize(ug, marg_vars = "B")),
    edges(caugi(A %---% C))
  )
})

test_that("anteriors returns list for multiple nodes", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  expect_warning(
    result <- anteriors(cg, c("A", "D")),
    "several nodes is deprecated"
  )
  expect_type(result, "list")
  expect_named(result, c("A", "D"))
  expect_null(result$A)
  expect_equal(sort(result$D), c("A", "B", "C"))
})

# ────────────────────────────── Posteriors tests ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("posteriors works for DAG (equals descendants)", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_equal(sort(posteriors(cg, "A")), c("B", "C"))
  expect_equal(posteriors(cg, "B"), "C")
  expect_null(posteriors(cg, "C"))
})

test_that("posteriors works for PDAG with mixed edges", {
  # PDAG: A -> B --- C, B -> D
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  # A's posteriors: B (child) -> C (undirected of B), D (child of B)
  expect_equal(sort(posteriors(cg, "A")), c("B", "C", "D"))
  # B's posteriors: D (child) and C (undirected)
  expect_equal(sort(posteriors(cg, "B")), c("C", "D"))
  # C's posteriors: B (undirected) -> D (child of B)
  expect_equal(sort(posteriors(cg, "C")), c("B", "D"))
  # D has no posteriors
  expect_null(posteriors(cg, "D"))
})

test_that("posteriors works for PDAG with undirected cycle", {
  # PDAG: A --- B --- C --- A (triangle)
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "PDAG"
  )
  # All nodes can reach all others via undirected edges
  # For undirected-only graphs, posteriors == anteriors
  expect_equal(sort(posteriors(cg, "A")), c("B", "C"))
  expect_equal(sort(posteriors(cg, "B")), c("A", "C"))
  expect_equal(sort(posteriors(cg, "C")), c("A", "B"))
})

test_that("posteriors returns list for multiple nodes", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )
  expect_warning(
    result <- posteriors(cg, c("A", "D")),
    "several nodes is deprecated"
  )
  expect_type(result, "list")
  expect_named(result, c("A", "D"))
  expect_equal(sort(result$A), c("B", "C", "D"))
  expect_null(result$D)
})

test_that("posteriors works with index parameter", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  # Index 1 is A (0-indexed becomes 1-indexed in R)
  expect_warning(
    po_1 <- posteriors(cg, index = 1),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_equal(sort(po_1), c("B", "C"))
  expect_warning(
    po_2 <- posteriors(cg, index = 2),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_equal(po_2, "C")
})

test_that("posteriors excludes the node itself", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  res <- posteriors(cg, "A")
  expect_false("A" %in% res)
})

test_that("posteriors handles multi-step mixed reachability (PDAG)", {
  # A -> B --- C --- D -> E
  cg <- caugi(
    A %-->% B,
    B %---% C,
    C %---% D,
    D %-->% E,
    class = "PDAG"
  )

  # From A: B, C, D, E should all be reachable
  expect_equal(sort(posteriors(cg, "A")), c("B", "C", "D", "E"))
})

test_that("posteriors does not return duplicates in undirected cycles", {
  # A --- B --- C --- A
  cg <- caugi(
    A %---% B,
    B %---% C,
    C %---% A,
    class = "PDAG"
  )

  res <- posteriors(cg, "A")
  expect_equal(length(res), length(unique(res)))
})

test_that("posteriors handles branching mixed structure correctly", {
  #      B --- C
  #     /
  # A ->
  #     \
  #      D -> E
  cg <- caugi(
    A %-->% B,
    B %---% C,
    A %-->% D,
    D %-->% E,
    class = "PDAG"
  )

  expect_equal(sort(posteriors(cg, "A")), c("B", "C", "D", "E"))
})

test_that("posteriors works for multiple starting nodes (set semantics)", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    class = "DAG"
  )

  expect_warning(
    res <- posteriors(cg, c("A", "D")),
    "several nodes is deprecated"
  )

  expect_type(res, "list")
  expect_named(res, c("A", "D"))

  expect_equal(sort(res$A), c("B", "C"))
  expect_equal(res$D, "E")
})

test_that("posteriors returns empty (NULL) when no reachable nodes exist", {
  cg <- caugi(
    A %-->% B,
    class = "DAG"
  )

  expect_null(posteriors(cg, "B"))
})

test_that("posteriors respects disconnected components", {
  cg <- caugi(
    A %-->% B,
    C %-->% D,
    class = "DAG"
  )

  expect_equal(posteriors(cg, "A"), "B")
  expect_equal(posteriors(cg, "C")[posteriors(cg, "C") == "A"], character(0))
})

test_that("posteriors index parameter matches name-based query", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  nodes_vec <- nodes(cg)
  idx_A <- which(nodes_vec == "A")

  expect_warning(
    po_A <- posteriors(cg, index = idx_A),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_equal(sort(po_A), sort(posteriors(cg, "A")))
})

# ──────────────────────────────────────────────────────────────────────────────
# ────────────────────────────── Closed graph definition tests ─────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("ancestors, anteriors, descendants, posteriors errors on not boolean open argument", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_error(
    ancestors(cg, "A", open = "hi"),
    "`open` must be a single TRUE or FALSE."
  )
  expect_error(
    anteriors(cg, "A", open = "hi"),
    "`open` must be a single TRUE or FALSE."
  )
  expect_error(
    descendants(cg, "A", open = "hi"),
    "`open` must be a single TRUE or FALSE."
  )
  expect_error(
    posteriors(cg, "A", open = c(TRUE, FALSE)),
    "`open` must be a single TRUE or FALSE."
  )
})

test_that("ancestors, anteriors, descendants, posteriors handles closed graph definition", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_equal(ancestors(cg, "A", open = FALSE), "A")
  expect_equal(ancestors(cg, "B", open = FALSE), c("B", "A"))

  expect_equal(anteriors(cg, "A", open = FALSE), "A")
  expect_equal(
    anteriors(cg, "C", open = FALSE),
    c("C", "A", "B")
  )

  expect_equal(
    descendants(cg, "A", open = FALSE),
    c("A", "B", "D")
  )
  expect_equal(descendants(cg, "B", open = FALSE), c("B", "D"))
  expect_equal(posteriors(cg, "A", open = FALSE), c("A", "B", "C", "D"))
  expect_equal(posteriors(cg, "B", open = FALSE), c("B", "C", "D"))
})

test_that("ancestors, anteriors, descendants, posteriors default to open = TRUE", {
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_null(ancestors(cg, "A"))
  expect_equal(ancestors(cg, "B"), "A")
  expect_null(anteriors(cg, "A"))
  expect_equal(anteriors(cg, "C"), c("A", "B"))
  expect_equal(descendants(cg, "A"), c("B", "D"))
  expect_equal(posteriors(cg, "A"), c("B", "C", "D"))
})

test_that("setting use_open_graph_definition warns and still sets the open default", {
  on.exit(caugi_options(reset = TRUE), add = TRUE)
  cg <- caugi(
    A %-->% B %---% C,
    B %-->% D,
    class = "PDAG"
  )

  expect_warning(
    caugi_options(use_open_graph_definition = FALSE),
    class = "deprecatedWarning"
  )
  expect_no_warning(
    expect_false(caugi_options("use_open_graph_definition"))
  )
  # Restoring all options does not warn
  expect_no_warning(caugi_options(caugi_options()))

  expect_equal(ancestors(cg, "B"), c("B", "A"))
  expect_equal(anteriors(cg, "C"), c("C", "A", "B"))
  expect_equal(descendants(cg, "A"), c("A", "B", "D"))
  expect_equal(posteriors(cg, "A"), c("A", "B", "C", "D"))

  # An explicit `open` overrides the option
  expect_equal(ancestors(cg, "B", open = TRUE), "A")
})

test_that("getter and districts branches are covered", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    B %---% D,
    class = "PDAG"
  )

  expect_warning(
    {
      expect_true("B" %in% ancestors(cg, index = 2, open = FALSE))
      expect_true("A" %in% descendants(cg, index = 1, open = FALSE))
      expect_true("D" %in% anteriors(cg, index = 4, open = FALSE))
    },
    "`index` argument is deprecated",
    fixed = TRUE
  )

  expect_error(
    posteriors(cg, nodes = "A", index = 1),
    "Supply either `nodes` or `index`, not both."
  )
  expect_error(
    posteriors(cg),
    "Supply one of `nodes` or `index`."
  )
  expect_error(
    posteriors(cg, nodes = 1),
    "`nodes` must be a character vector of node names."
  )
  expect_warning(
    po_B <- posteriors(cg, index = 2, open = FALSE),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_true("B" %in% po_B)

  cg_admg <- caugi(
    A %<->% B,
    B %<->% C,
    C %-->% D,
    class = "ADMG"
  )
  expect_warning(
    sp_2 <- spouses(cg_admg, index = 2),
    "`index` argument is deprecated",
    fixed = TRUE
  )
  expect_setequal(sp_2, c("A", "C"))

  # Test that deprecated 'all' parameter shows warning
  expect_warning(
    districts(cg_admg, all = TRUE),
    "deprecated"
  )

  # Test error for invalid index
  expect_error(
    districts(cg_admg, index = c(1, NA)),
    "`index` must be numeric without NA."
  )

  # Test getting all districts (new API - no parameters)
  all_districts <- districts(cg_admg)
  expect_true(is.list(all_districts))
  expect_true(length(all_districts) >= 1L)
})

test_that("is_mag class short-circuit branch is covered", {
  cg <- caugi(A %-->% B, class = "DAG")
  out <- testthat::with_mocked_bindings(
    is_mag(cg),
    rs_class = function(session) "MAG",
    .package = "caugi"
  )
  expect_true(out)
})

test_that("nodes_to_indices errors when session is missing", {
  cg <- caugi(A %-->% B, class = "DAG")
  bad <- cg
  attr(bad, "session") <- NULL
  expect_error(
    caugi:::.nodes_to_indices(bad, "A"),
    "Cannot look up indices for empty graph."
  )
})


################# NetworkX tests ##############
# topological sort tests:
# https://github.com/networkx/networkx/blob/main/networkx/algorithms/tests/test_dag.py
# All the other ones are just raising errors, etc, and thus only the below are ported.

test_that("topological sort NetworkX 1 test", {
  cg <- caugi(A %-->% B + C, B %-->% C, class = "DAG")
  ts_cg <- topological_sort(cg)
  expect_equal(ts_cg, c("A", "B", "C"))

  cg <- caugi(A %-->% B + C, C %-->% B, class = "DAG")
  ts_cg <- topological_sort(cg)
  expect_equal(ts_cg, c("A", "C", "B"))
})

test_that("topological sort NetworkX 2 test", {
  cg <- caugi(A %-->% B, B %-->% C, C %-->% D, D %-->% E, class = "DAG")
  ts_cg <- topological_sort(cg)
  expect_equal(ts_cg, c("A", "B", "C", "D", "E"))

  cg <- caugi(A %-->% B + C, C %-->% B, class = "DAG")
  ts_cg <- topological_sort(cg)
  expect_equal(ts_cg, c("A", "C", "B"))
})


# ancestors and descendants tests:
# https://github.com/networkx/networkx/blob/main/networkx/algorithms/tests/test_dag.py

test_that("ancestors NetworkX 1 test", {
  cg <- caugi(
    A %-->% B + C,
    D %-->% B + E,
    D %-->% C,
    B %-->% F,
    E %-->% F,
    class = "DAG"
  )
  ancestors_cg_f <- ancestors(cg, nodes = "F")
  expect_setequal(ancestors_cg_f, c("A", "B", "D", "E"))

  ancestors_cg_c <- ancestors(cg, nodes = "C")
  expect_setequal(ancestors_cg_c, c("A", "D"))

  ancestors_cg_a <- ancestors(cg, nodes = "A")
  expect_null(ancestors_cg_a)
})

test_that("descendants NetworkX 1 test", {
  cg <- caugi(
    A %-->% B + C,
    D %-->% B + E,
    D %-->% C,
    B %-->% F,
    E %-->% F,
    class = "DAG"
  )
  descendants_cg_a <- descendants(cg, nodes = "A")
  expect_setequal(descendants_cg_a, c("B", "C", "F"))

  descendants_cg_d <- descendants(cg, nodes = "D")
  expect_setequal(descendants_cg_d, c("B", "C", "E", "F"))

  descendants_cg_c <- descendants(cg, nodes = "C")
  expect_null(descendants_cg_c)
})

# ──────────────────────────────────────────────────────────────────────────────
# ─────────────── Deprecated per-node lists for several nodes (#359) ───────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("the several-nodes warning is a classed deprecatedWarning", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  cnd <- tryCatch(parents(cg, c("B", "C")), warning = identity)
  expect_s3_class(cnd, c("caugi_deprecated_node_list", "deprecatedWarning"))
  expect_match(conditionMessage(cnd), "union of the results", fixed = TRUE)
  expect_match(conditionMessage(cnd), "`lapply()`", fixed = TRUE)
})

test_that("parents() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_warning(
    res <- parents(cg, c("B", "C")),
    "`parents()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(B = "A", C = "B"))
  expect_warning(
    res <- parents(cg, index = 2:3),
    "`parents()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(B = "A", C = "B"))
})

test_that("children() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_warning(
    res <- children(cg, c("A", "C")),
    "`children()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = "B", C = NULL))
})

test_that("neighbors() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_warning(
    res <- neighbors(cg, c("A", "B")),
    "`neighbors()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = "B", B = c("A", "C")))
  expect_warning(
    res <- neighbours(cg, c("A", "B")),
    "`neighbors()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = "B", B = c("A", "C")))
})

test_that("ancestors() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_warning(
    res <- ancestors(cg, c("A", "C")),
    "`ancestors()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = NULL, C = c("A", "B")))
})

test_that("descendants() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_warning(
    res <- descendants(cg, c("A", "C")),
    "`descendants()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = c("B", "C"), C = NULL))
})

test_that("anteriors() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B %---% C, class = "PDAG")
  expect_warning(
    res <- anteriors(cg, c("A", "C")),
    "`anteriors()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = NULL, C = c("A", "B")))
})

test_that("posteriors() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %-->% B %---% C, class = "PDAG")
  expect_warning(
    res <- posteriors(cg, c("A", "C")),
    "`posteriors()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = c("B", "C"), C = "B"))
})

test_that("markov_blanket() with several nodes warns and returns the list", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  expect_warning(
    res <- markov_blanket(cg, c("A", "B")),
    "`markov_blanket()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = "B", B = c("A", "C")))
})

test_that("spouses() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %<->% B, B %<->% C, A %-->% C, class = "ADMG")
  expect_warning(
    res <- spouses(cg, c("A", "B")),
    "`spouses()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = "B", B = c("A", "C")))
})

test_that("districts() with several nodes warns and returns the per-node list", {
  cg <- caugi(A %<->% B, B %<->% C, A %-->% C, D, class = "ADMG")
  expect_warning(
    res <- districts(cg, nodes = c("A", "D")),
    "`districts()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = c("A", "B", "C"), D = "D"))
  expect_warning(
    res <- districts(cg, index = c(1, 4)),
    "`districts()` with several nodes is deprecated",
    fixed = TRUE
  )
  expect_identical(res, list(A = c("A", "B", "C"), D = "D"))
})

test_that("single-node queries and districts(cg) do not warn", {
  dag <- caugi(A %-->% B, B %-->% C, class = "DAG")
  pdag <- caugi(A %-->% B %---% C, class = "PDAG")
  admg <- caugi(A %<->% B, B %<->% C, A %-->% C, D, class = "ADMG")
  expect_no_warning(parents(dag, "B"))
  expect_no_warning(children(dag, "C"))
  expect_no_warning(neighbors(dag, "B"))
  expect_no_warning(neighbours(dag, "B"))
  expect_no_warning(ancestors(dag, "C"))
  expect_no_warning(descendants(dag, "A"))
  expect_no_warning(anteriors(pdag, "C"))
  expect_no_warning(posteriors(pdag, "A"))
  expect_no_warning(markov_blanket(dag, "B"))
  expect_no_warning(spouses(admg, "B"))
  expect_no_warning(districts(admg, nodes = "A"))
  expect_no_warning(districts(admg))
})

test_that("condition_marginalize() does not trigger the several-nodes warning", {
  cg <- caugi(A %-->% B, B %-->% C, C %<->% D, D %-->% E, class = "ADMG")
  expect_no_warning(
    out <- condition_marginalize(cg, marg_vars = "B", cond_vars = "D")
  )
  expect_identical(out@edges$edge, "-->")
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────── Deprecated index arguments (#360) ──────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("the index-argument warning is a classed deprecatedWarning", {
  cg <- caugi(A %-->% B, B %-->% C, class = "DAG")
  cnd <- tryCatch(parents(cg, index = 2), warning = identity)
  expect_s3_class(cnd, "caugi_deprecated_index")
  expect_s3_class(cnd, "deprecatedWarning")
  expect_match(
    conditionMessage(cnd),
    "`nodes = nodes(cg)$name[index]`",
    fixed = TRUE
  )
  cnd <- tryCatch(d_separated(cg, X_index = 1, Y = "C"), warning = identity)
  expect_s3_class(cnd, "caugi_deprecated_index")
  expect_match(
    conditionMessage(cnd),
    "`X = nodes(cg)$name[X_index]`",
    fixed = TRUE
  )
})

test_that("index arguments warn and give the same result as node names", {
  # Checks that `by_index` warns once for each index argument in `args`, with
  # at most one other warning (from a deprecated wrapper or several nodes),
  # and returns the same as `by_name`.
  expect_index_deprecated <- function(by_index, by_name, args) {
    msgs <- character(0)
    res <- withCallingHandlers(
      by_index,
      warning = function(w) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    pattern <- "^The `([A-Za-z_]+)` argument is deprecated.*$"
    is_index <- grepl(pattern, msgs)
    expect_identical(sort(sub(pattern, "\\1", msgs[is_index])), sort(args))
    expect_lte(sum(!is_index), 1L)
    expect_identical(res, by_name)
  }
  parts <- function(cg) list(cg@nodes, cg@edges)

  dag <- caugi(U %-->% X + Y, X %-->% M, M %-->% Y, class = "DAG")
  admg <- caugi(L %-->% X + Y, X %-->% Y, X %<->% W, class = "ADMG")
  expect_identical(dag@nodes$name, c("U", "X", "M", "Y"))
  expect_identical(admg@nodes$name, c("L", "X", "Y", "W"))

  expect_index_deprecated(parents(dag, index = 4), parents(dag, "Y"), "index")
  expect_index_deprecated(
    parents(dag, index = c(2, 4)),
    suppressWarnings(parents(dag, c("X", "Y"))),
    "index"
  )
  expect_index_deprecated(children(dag, index = 1), children(dag, "U"), "index")
  expect_index_deprecated(
    neighbors(dag, index = 2),
    neighbors(dag, "X"),
    "index"
  )
  expect_index_deprecated(
    neighbours(dag, index = 2),
    neighbours(dag, "X"),
    "index"
  )
  expect_index_deprecated(
    ancestors(dag, index = 4),
    ancestors(dag, "Y"),
    "index"
  )
  expect_index_deprecated(
    descendants(dag, index = 1),
    descendants(dag, "U"),
    "index"
  )
  expect_index_deprecated(
    anteriors(dag, index = 4),
    anteriors(dag, "Y"),
    "index"
  )
  expect_index_deprecated(
    posteriors(dag, index = 1),
    posteriors(dag, "U"),
    "index"
  )
  expect_index_deprecated(
    markov_blanket(dag, index = 2),
    markov_blanket(dag, "X"),
    "index"
  )
  expect_index_deprecated(spouses(admg, index = 2), spouses(admg, "X"), "index")
  expect_index_deprecated(
    districts(admg, index = 2),
    districts(admg, nodes = "X"),
    "index"
  )
  expect_index_deprecated(
    parts(subgraph(dag, index = c(2, 3))),
    parts(subgraph(dag, c("X", "M"))),
    "index"
  )

  XYZ <- c("X_index", "Y_index", "Z_index")
  expect_index_deprecated(
    d_separated(dag, X_index = 2, Y_index = 4, Z_index = c(1, 3)),
    d_separated(dag, "X", "Y", Z = c("U", "M")),
    XYZ
  )
  expect_index_deprecated(
    m_separated(dag, X_index = 2, Y_index = 4, Z_index = c(1, 3)),
    m_separated(dag, "X", "Y", Z = c("U", "M")),
    XYZ
  )
  expect_index_deprecated(
    adjustment_set(dag, X_index = 2, Y_index = 4),
    adjustment_set(dag, "X", "Y"),
    XYZ[1:2]
  )
  expect_index_deprecated(
    is_valid_adjustment(dag, X_index = 2, Y_index = 4, Z_index = 1),
    is_valid_adjustment(dag, "X", "Y", Z = "U"),
    XYZ
  )
  expect_index_deprecated(
    is_valid_backdoor(dag, X_index = 2, Y_index = 4, Z_index = 1),
    is_valid_adjustment(dag, "X", "Y", Z = "U", type = "backdoor"),
    XYZ
  )
  expect_index_deprecated(
    is_valid_adjustment_admg(admg, X_index = 2, Y_index = 3, Z_index = 1),
    is_valid_adjustment(admg, "X", "Y", Z = "L"),
    XYZ
  )
  expect_index_deprecated(
    all_adjustment_sets(dag, X_index = 2, Y_index = 4),
    all_adjustment_sets(dag, "X", "Y"),
    XYZ[1:2]
  )
  expect_index_deprecated(
    all_backdoor_sets(dag, X_index = 2, Y_index = 4),
    all_adjustment_sets(dag, "X", "Y", type = "backdoor"),
    XYZ[1:2]
  )
  expect_index_deprecated(
    all_adjustment_sets_admg(admg, X_index = 2, Y_index = 3),
    all_adjustment_sets(admg, "X", "Y"),
    XYZ[1:2]
  )

  XYIR <- c("X_index", "Y_index", "I_index", "R_index")
  expect_index_deprecated(
    minimal_separator(
      dag,
      I = NULL,
      X_index = 2,
      Y_index = 4,
      I_index = 1,
      R_index = c(1, 3)
    ),
    minimal_separator(dag, "X", "Y", I = "U", R = c("U", "M")),
    XYIR
  )
  expect_index_deprecated(
    minimal_d_separator(
      dag,
      I = NULL,
      X_index = 2,
      Y_index = 4,
      I_index = 1,
      R_index = c(1, 3)
    ),
    minimal_separator(dag, "X", "Y", I = "U", R = c("U", "M")),
    XYIR
  )
})
