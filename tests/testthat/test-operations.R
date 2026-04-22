# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Skeleton ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("DAG --> UG with skeleton keeps the skeleton", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    D %-->% E,
    F,
    G,
    class = "DAG"
  )

  skel_cg <- skeleton(cg)

  expect_equal(edge_types(skel_cg), "---")
  expect_equal(length(skel_cg), 7)
  expect_equal(nodes(cg), nodes(skel_cg))
  expect_equal(edges(cg)$from, edges(skel_cg)$from)
  expect_equal(edges(cg)$to, edges(skel_cg)$to)
})

test_that("PDAG --> UG with skeleton keeps the skeleton", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %---% D,
    D %-->% E,
    F,
    G,
    class = "PDAG"
  )

  skel_cg <- skeleton(cg)

  expect_equal(edge_types(skel_cg), "---")
  expect_equal(length(skel_cg), 7)
  expect_equal(nodes(cg), nodes(skel_cg))
  expect_equal(edges(cg)$from, edges(skel_cg)$from)
  expect_equal(edges(cg)$to, edges(skel_cg)$to)
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Moralizing ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("moralize works on DAGs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% C,
    E %-->% C,
    D %-->% B,
    F,
    G,
    nodes = c("A", "B", "C", "D", "E", "F", "G"),
    class = "DAG"
  )

  moralized_cg <- moralize(cg)

  expect_equal(edge_types(moralized_cg), "---")
  expect_equal(length(moralized_cg), 7)
  expect_equal(nodes(cg), nodes(moralized_cg))
  expect_equal(moralized_cg@graph_class, "UG")

  expected_moral_cg <- caugi(
    A %---% B,
    A %---% D,
    B %---% C,
    B %---% D,
    B %---% E,
    C %---% D,
    C %---% E,
    D %---% E,
    F,
    G,
    nodes = c("A", "B", "C", "D", "E", "F", "G"),
    class = "UG"
  )
  expect_equal(edges(moralized_cg), edges(expected_moral_cg))
})

test_that("moralize fails on non-DAGs", {
  cg_pdag <- caugi(
    A %-->% B,
    B %-->% C,
    C %---% D,
    class = "PDAG"
  )

  expect_error(
    moralize(cg_pdag),
    "moralize\\(\\) can only be applied to DAGs\\."
  )

  cg_ug <- caugi(
    A %---% B,
    B %---% C,
    class = "UG"
  )

  expect_error(
    moralize(cg_ug),
    "moralize\\(\\) can only be applied to DAGs\\."
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Mutation ───────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("mutate_caugi throws error, when mutation isn't possible", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %---% D,
    D %-->% E,
    F,
    G,
    class = "PDAG"
  )

  is_it <- is_dag(cg)
  expect_false(is_it)
  expect_error(mutate_caugi(cg, class = "DAG"), "Cannot convert caugi of class")
})

test_that("mutate_caugi works for all classes to UNKNOWN", {
  cg_pdag <- caugi(
    A %-->% B,
    B %-->% C,
    C %---% D,
    D %-->% E,
    F,
    G,
    class = "PDAG"
  )
  cg_dag <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    F,
    G,
    class = "DAG"
  )
  cg_ug <- caugi(
    A %---% B,
    B %---% C,
    C %---% D,
    D %---% E,
    F,
    G,
    class = "UG"
  )
  cg_unknown_pdag <- mutate_caugi(cg_pdag, class = "UNKNOWN")
  cg_unknown_dag <- mutate_caugi(cg_dag, class = "UNKNOWN")
  cg_unknown_ug <- mutate_caugi(cg_ug, class = "UNKNOWN")
  expect_equal(cg_unknown_pdag@graph_class, "UNKNOWN")
  expect_equal(cg_unknown_dag@graph_class, "UNKNOWN")
  expect_equal(cg_unknown_ug@graph_class, "UNKNOWN")

  expect_equal(edges(cg_unknown_pdag), edges(cg_pdag))
  expect_equal(edges(cg_unknown_dag), edges(cg_dag))
  expect_equal(edges(cg_unknown_ug), edges(cg_ug))

  expect_equal(nodes(cg_unknown_pdag), nodes(cg_pdag))
  expect_equal(nodes(cg_unknown_dag), nodes(cg_dag))
  expect_equal(nodes(cg_unknown_ug), nodes(cg_ug))
})

test_that("mutate_caugi works from UNKNOWN to DAG", {
  cg_unknown <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    F,
    G,
    class = "UNKNOWN"
  )
  is_it <- is_dag(cg_unknown)
  expect_true(is_it)

  cg_dag <- mutate_caugi(cg_unknown, class = "DAG")
  expect_equal(cg_dag@graph_class, "DAG")
  expect_equal(edges(cg_dag), edges(cg_unknown))
  expect_equal(nodes(cg_dag), nodes(cg_unknown))
})

test_that("mutate_caugi works from DAG to PDAG", {
  cg_dag <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    F,
    G,
    class = "DAG"
  )

  cg_pdag <- mutate_caugi(cg_dag, class = "PDAG")
  expect_equal(cg_pdag@graph_class, "PDAG")
  expect_equal(edges(cg_pdag), edges(cg_dag))
  expect_equal(nodes(cg_pdag), nodes(cg_dag))
})

test_that("mutate_caugi works from PDAG to DAG if PDAG is a DAG", {
  cg_pdag <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    F,
    G,
    class = "PDAG"
  )
  is_it <- is_dag(cg_pdag)
  expect_true(is_it)

  cg_dag <- mutate_caugi(cg_pdag, class = "DAG")
  expect_equal(cg_dag@graph_class, "DAG")
  expect_equal(edges(cg_dag), edges(cg_pdag))
  expect_equal(nodes(cg_dag), nodes(cg_pdag))
})

test_that("mutate_caugi works on empty caugi", {
  cg_empty <- caugi(class = "DAG")
  cg_empty_ug <- mutate_caugi(cg_empty, class = "UG")
  expect_equal(length(cg_empty_ug), 0)
  expect_equal(cg_empty_ug@graph_class, "UG")
})

test_that("mutate_caugi doesn't change class if old class is equal to new class", {
  cg_dag <- caugi(
    A %-->% B,
    B %-->% C,
    D %-->% E,
    F,
    G,
    class = "DAG"
  )

  cg_dag_mutated <- mutate_caugi(cg_dag, class = "DAG")
  expect_equal(cg_dag_mutated@graph_class, "DAG")
  expect_equal(edges(cg_dag_mutated), edges(cg_dag))
  expect_equal(nodes(cg_dag_mutated), nodes(cg_dag))
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────── Latent Projection ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("latent_project basic confounding: U -> X, U -> Y, X -> Y", {
  # DAG: U -> X, U -> Y, X -> Y
  # Project out U:
  # - U has Ch(U) = {X, Y}
  # - Step 3: Add X <-> Y (children of U pair up)
  # Result: X -> Y AND X <-> Y
  dag <- caugi(
    U %-->% X,
    U %-->% Y,
    X %-->% Y,
    class = "DAG"
  )

  admg <- latent_project(dag, latents = "U")

  expect_equal(admg@graph_class, "ADMG")
  expect_equal(length(admg), 2)
  expect_equal(sort(nodes(admg)$name), c("X", "Y"))

  # Check directed edge X -> Y preserved
  expect_equal(parents(admg, "Y"), "X")
  expect_equal(children(admg, "X"), "Y")

  # X <-> Y added
  expect_equal(spouses(admg, "X"), "Y")
  expect_equal(spouses(admg, "Y"), "X")
})

test_that("latent_project with no latents returns the same graph as ADMG", {
  dag <- caugi(
    X %-->% Y,
    Y %-->% Z,
    class = "DAG"
  )

  admg <- latent_project(dag, latents = character(0))

  expect_equal(admg@graph_class, "ADMG")
  expect_equal(length(admg), 3)
  expect_equal(nodes(admg)$name, c("X", "Y", "Z"))

  # Same directed edges
  expect_equal(parents(admg, "Y"), "X")
  expect_equal(parents(admg, "Z"), "Y")

  # No bidirected edges (returns NULL when no spouses)
  expect_null(spouses(admg, "X"))
  expect_null(spouses(admg, "Y"))
  expect_null(spouses(admg, "Z"))
})

test_that("latent_project with multiple latents", {
  # DAG: L1 -> X, L1 -> Y, L2 -> Y, L2 -> Z, X -> Y, Y -> Z
  # Project out L1, L2
  #
  # Eliminate L1:
  # - Ch(L1) = {X, Y}
  # - Step 3: Add X <-> Y
  #
  # Eliminate L2:
  # - Ch(L2) = {Y, Z}
  # - Step 3: Add Y <-> Z
  #
  # Result: X -> Y -> Z (directed) + X <-> Y, Y <-> Z (bidirected)
  dag <- caugi(
    L1 %-->% X,
    L1 %-->% Y,
    L2 %-->% Y,
    L2 %-->% Z,
    X %-->% Y,
    Y %-->% Z,
    class = "DAG"
  )

  admg <- latent_project(dag, latents = c("L1", "L2"))

  expect_equal(admg@graph_class, "ADMG")
  expect_equal(length(admg), 3)
  expect_equal(nodes(admg)$name, c("X", "Y", "Z"))

  # Directed edges preserved
  expect_equal(parents(admg, "Y"), "X")
  expect_equal(parents(admg, "Z"), "Y")

  # - X <-> Y: added (children of L1 pair up)
  # - Y <-> Z: added (children of L2 pair up)
  expect_equal(spouses(admg, "X"), "Y")
  expect_equal(sort(spouses(admg, "Y")), c("X", "Z"))
  expect_equal(spouses(admg, "Z"), "Y")
})

test_that("latent_project with latent chain", {
  # DAG: L1 -> L2 -> X, L2 -> Y
  # Project out L1, L2
  # X and Y share latent ancestor L2, so X <-> Y
  dag <- caugi(
    L1 %-->% L2,
    L2 %-->% X,
    L2 %-->% Y,
    class = "DAG"
  )

  admg <- latent_project(dag, latents = c("L1", "L2"))

  expect_equal(admg@graph_class, "ADMG")
  expect_equal(length(admg), 2)
  expect_equal(nodes(admg)$name, c("X", "Y"))

  # No directed edges between X and Y (returns NULL when no children)
  expect_null(children(admg, "X"))
  expect_null(children(admg, "Y"))

  # X <-> Y from shared ancestor L2
  expect_equal(spouses(admg, "X"), "Y")
  expect_equal(spouses(admg, "Y"), "X")
})

test_that("latent_project all nodes latent returns empty ADMG", {
  dag <- caugi(
    L1 %-->% L2,
    class = "DAG"
  )

  admg <- latent_project(dag, latents = c("L1", "L2"))

  expect_equal(admg@graph_class, "ADMG")
  expect_equal(length(admg), 0)
})

test_that("latent_project no shared latent ancestors (no bidirected edges)", {
  # DAG: U -> X, V -> Y (no shared ancestor)
  # Project out U, V
  # Result: X, Y (isolated nodes, no edges)
  dag <- caugi(
    U %-->% X,
    V %-->% Y,
    class = "DAG"
  )

  admg <- latent_project(dag, latents = c("U", "V"))

  expect_equal(admg@graph_class, "ADMG")
  expect_equal(length(admg), 2)

  # No edges at all (returns NULL when no children/spouses)
  expect_null(children(admg, "X"))
  expect_null(children(admg, "Y"))
  expect_null(spouses(admg, "X"))
  expect_null(spouses(admg, "Y"))
})

test_that("latent_project fails on non-DAGs", {
  cg_pdag <- caugi(
    A %-->% B,
    B %---% C,
    class = "PDAG"
  )

  expect_error(
    latent_project(cg_pdag, latents = "A"),
    "latent_project\\(\\) can only be applied to DAGs\\."
  )

  cg_ug <- caugi(
    A %---% B,
    class = "UG"
  )

  expect_error(
    latent_project(cg_ug, latents = "A"),
    "latent_project\\(\\) can only be applied to DAGs\\."
  )
})

test_that("latent_project fails with unknown latent names", {
  dag <- caugi(
    X %-->% Y,
    class = "DAG"
  )

  expect_error(
    latent_project(dag, latents = "Z"),
    "Unknown latent node\\(s\\): Z"
  )

  expect_error(
    latent_project(dag, latents = c("X", "Z", "W")),
    "Unknown latent node\\(s\\): Z, W"
  )
})

test_that("latent_project fails with non-character latents", {
  dag <- caugi(
    X %-->% Y,
    class = "DAG"
  )

  expect_error(
    latent_project(dag, latents = 1),
    "`latents` must be a character vector"
  )
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── Exogenize ──────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("exogenize works", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  exogenized_cg <- exogenize(cg, nodes = "B")
  cg_expected <- caugi(
    A %-->% C,
    B %-->% C,
    class = "DAG"
  )
  # Compare edges irrespective of order
  actual <- edges(exogenized_cg)[order(from, to, edge)]
  expected <- edges(cg_expected)[order(from, to, edge)]
  expect_equal(actual, expected)
  expect_setequal(nodes(exogenized_cg)$name, nodes(cg_expected)$name)
})

test_that("exogenize fails with nodes not in graph", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_error(exogenize(cg, nodes = "D"), "Node D not in graph.")
})

test_that("exogenize fails with non-character nodes", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_error(
    exogenize(cg, nodes = 1),
    "`nodes` must be a non-empty character vector of node names."
  )
  expect_error(
    exogenize(cg, nodes = character(0)),
    "`nodes` must be a non-empty character vector of node names."
  )
})

test_that("exogenize agrees with exogenous query", {
  cg <- generate_graph(n = 100, m = 10, class = "DAG")
  exogenous_nodes <- exogenous(cg)
  new_exogenous_nodes <- sample(nodes(cg)$name, size = 10)
  exogenized_cg <- exogenize(cg, nodes = new_exogenous_nodes)
  expect_setequal(
    exogenous(exogenized_cg),
    union(exogenous_nodes, new_exogenous_nodes)
  )
})

test_that("exogenize supports multiple nodes", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% D,
    class = "DAG"
  )
  exogenized_cg <- exogenize(cg, nodes = c("B", "C"))

  expect_null(parents(exogenized_cg, "B"))
  expect_null(parents(exogenized_cg, "C"))
  expect_setequal(parents(exogenized_cg, "D"), c("B", "C", "A"))
})

test_that("exogenize handles duplicate node inputs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )

  exo_once <- exogenize(cg, nodes = "B")
  exo_twice <- exogenize(cg, nodes = c("B", "B"))

  actual_once <- edges(exo_once)[order(from, to, edge)]
  actual_twice <- edges(exo_twice)[order(from, to, edge)]
  expect_equal(actual_once, actual_twice)
})

test_that("exogenize fails with non-simple graphs", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "UNKNOWN"
  )
  expect_error(
    exogenize(cg, nodes = "B"),
    "`cg` must be a DAG"
  )
})


test_that("Marginalization and conditioning work", {
  ## Examples from Figure 10 of Richardson and Spirtes 2002

  mg <- caugi(U %-->% X + Y, A %-->% X, B %-->% Y, class = "DAG")

  mgmu <- condition_marginalize(mg, marg_vars = "U")
  resmu <- caugi(A %-->% X, B %-->% Y, X %<->% Y, class = "AG")

  same_graphs <- function(cg1, cg2) {
    if (!cg1@graph_class == cg2@graph_class) {
      FALSE
    }
    if (!setequal(nodes(cg1)$name, nodes(cg2)$name)) {
      FALSE
    }

    shd(cg1, cg2) == 0
  }

  expect_true(same_graphs(mgmu, resmu))

  rescu <- caugi(A %-->% X, B %-->% Y)
  mgcu <- condition_marginalize(mg, cond_vars = "U")

  expect_true(same_graphs(rescu, mgcu))

  expect_error(condition_marginalize(mg, cond_vars = NULL, marg_vars = NULL))

  # Figure 11

  f11 <- caugi(
    A %-->% L1,
    L1 %-->% B,
    L2 %-->% B + C,
    B %-->% S,
    S %-->% D,
    D %-->% C
  )

  f11.cS <- condition_marginalize(f11, cond_vars = "S")
  f11.mL1L2 <- condition_marginalize(f11, marg_vars = c("L1", "L2"))
  f11.cSmL1L2 <- condition_marginalize(
    f11,
    marg_vars = c("L1", "L2"),
    cond_vars = "S"
  )

  f11.ii <- caugi(
    A %---% L1,
    L1 %---% L2 + B,
    L2 %---% B,
    L2 %-->% C,
    D %-->% C,
    class = "AG"
  )
  f11.iii <- caugi(
    A %-->% B + C,
    B %-->% S + C,
    S %-->% D,
    D %-->% C,
    class = "AG"
  )
  f11.iv <- caugi(A %---% B, A %-->% C, B %-->% C, D %-->% C, class = "AG")

  expect_true(same_graphs(f11.cS, f11.ii))
  expect_true(same_graphs(f11.mL1L2, f11.iii))
  expect_true(same_graphs(f11.cSmL1L2, f11.iv))

  ## order doesn't matter

  expect_true(same_graphs(
    condition_marginalize(f11.cS, marg_vars = c("L1", "L2")),
    f11.cSmL1L2
  ))
  expect_true(same_graphs(
    condition_marginalize(f11.mL1L2, cond_vars = "S"),
    f11.cSmL1L2
  ))

  ## error checking

  emg <- caugi(U %-->% X + Y, A %-->% X, B %-->% Y, K %<->% Y, class = "AG")

  expect_no_error(condition_marginalize(emg, cond_vars = "U"))
  expect_error(condition_marginalize(
    f11,
    cond_vars = c("S", "L1"),
    marg_vars = c("L1")
  ))
})

# ──────────────────────────────────────────────────────────────────────────────
# ───────────────────────────────── DAG from PDAG ──────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("dag_from_pdag converts a valid PDAG to a DAG", {
  PDAG <- caugi(
    A %---% B,
    B %---% C,
    class = "PDAG"
  )
  DAG <- dag_from_pdag(PDAG)
  edges_DAG <- edges(DAG)
  expect_true(all(edges_DAG$edge == "-->"))
})

test_that("dag_from_pdag errors on non-PDAG input", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    class = "DAG"
  )
  expect_error(dag_from_pdag(cg), "Input must be a caugi PDAG graph")
})

test_that("dag_from_pdag errors if PDAG cannot be extended to a DAG", {
  PDAG <- caugi(
    A %---% B,
    A %---% D,
    B %---% C,
    C %---% D,
    class = "PDAG"
  )
  expect_error(dag_from_pdag(PDAG), "PDAG cannot be extended to a DAG")
})

# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────── Meek closure ───────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────

test_that("meek_closure orients compelled edges and returns an MPDAG", {
  check_oriented <- function(g, from, to) {
    expect_true(to %in% children(g, from))
    if (is_dag(g)) {
      return()
    } else {
      und <- neighbors(g, from, mode = "undirected")
      if (is.null(und)) {
        und <- character(0)
      }
      expect_false(to %in% und)
    }
  }

  # R1: A -> B, C -> B, B -- D, and C !~ D  =>  B -> D
  g_r1 <- caugi(
    A %-->% B,
    C %-->% B,
    B %---% D,
    A %---% D,
    class = "PDAG"
  )
  c_r1 <- meek_closure(g_r1)
  check_oriented(c_r1, "B", "D")
  expect_true(is_mpdag(c_r1))

  # R2: A -- B and A -> C -> B  =>  A -> B
  g_r2 <- caugi(
    A %---% B,
    A %-->% C,
    C %-->% B,
    class = "PDAG"
  )
  c_r2 <- meek_closure(g_r2)
  check_oriented(c_r2, "A", "B")
  expect_true(is_mpdag(c_r2))

  # R3: A -- B, C -> B, D -> B, C !~ D, A -- C, A -- D  =>  A -> B
  g_r3 <- caugi(
    A %---% B,
    C %-->% B,
    D %-->% B,
    A %---% C,
    A %---% D,
    class = "PDAG"
  )
  c_r3 <- meek_closure(g_r3)
  check_oriented(c_r3, "A", "B")
  expect_true(is_mpdag(c_r3))

  # R4: A -- B and A => B through A -> C -> D -> B  =>  A -> B
  g_r4 <- caugi(
    A %---% B,
    A %-->% C,
    C %-->% D,
    A %---% D,
    D %-->% B,
    class = "PDAG"
  )
  c_r4 <- meek_closure(g_r4)
  check_oriented(c_r4, "A", "B")
  expect_true(is_mpdag(c_r4))
})

test_that("meek_closure is idempotent and preserves node names", {
  g <- caugi(
    B %---% A,
    B %---% D,
    C %-->% E,
    B %-->% E,
    D %-->% F,
    E %-->% F,
    class = "PDAG"
  )

  c1 <- meek_closure(g)
  c2 <- meek_closure(c1)

  expect_equal(c1@graph_class, "PDAG")
  expect_equal(nodes(c1)$name, nodes(g)$name)
  expect_equal(edges(c1), edges(c2))
})

test_that("meek_closure errors on non-PDAG-compatible graphs", {
  g <- caugi(A %o->% B, class = "UNKNOWN")
  expect_error(
    meek_closure(g),
    "meek_closure\\(\\) can only be applied to PDAGs\\."
  )
})

test_that("meek_closure matches causal-learn style multi-rule regression", {
  # Skeleton: A-B-C, A->D<-C, B-D, D-E, C-E
  # Meek progression:
  #   R1: D -> E
  #   R2: C -> E
  #   R3: B -> D
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

  g_closed <- meek_closure(g)

  expected <- caugi(
    A %---% B,
    B %---% C,
    A %-->% D,
    B %-->% D,
    C %-->% D,
    D %-->% E,
    C %-->% E,
    class = "PDAG"
  )

  norm_edges <- function(x) edges(x)[order(from, to, edge)]
  expect_equal(norm_edges(g_closed), norm_edges(expected))

  # Invariants inspired by CPDAG/Meek references.
  expect_equal(
    norm_edges(skeleton(g_closed)),
    norm_edges(skeleton(g))
  )
  expect_true(is_acyclic(g_closed, force_check = TRUE))
  expect_true(is_mpdag(g_closed))
})

test_that("dag_from_pdag preserves directed edges in mixed extension cases", {
  pdag <- caugi(
    A %-->% B,
    C %-->% B,
    C %---% D,
    D %---% A,
    class = "PDAG"
  )

  dag <- dag_from_pdag(pdag)
  ed <- edges(dag)
  has_dir <- function(from, to) {
    any(ed$from == from & ed$to == to & ed$edge == "-->")
  }

  expect_true(is_dag(dag))
  expect_true(has_dir("A", "B"))
  expect_true(has_dir("C", "B"))
  expect_true(xor(has_dir("A", "D"), has_dir("D", "A")))
  expect_true(xor(has_dir("C", "D"), has_dir("D", "C")))
  expect_false(has_dir("A", "D") && has_dir("C", "D"))
  expect_equal(nrow(ed), 4L)
})

test_that("dag_from_pdag orients each undirected edge exactly once", {
  pdag <- caugi(
    A %-->% C,
    B %-->% C,
    A %---% D,
    class = "PDAG"
  )

  dag <- dag_from_pdag(pdag)
  ed <- edges(dag)
  has_dir <- function(from, to) {
    any(ed$from == from & ed$to == to & ed$edge == "-->")
  }

  expect_true(has_dir("A", "C"))
  expect_true(has_dir("B", "C"))
  expect_true(xor(has_dir("A", "D"), has_dir("D", "A")))
  expect_false(any(ed$edge == "---"))
  expect_equal(nrow(ed), 3L)
})

test_that("pgmpy Meek fixtures: rs_to_cpdag on PDAG applies Meek closure", {
  cpdag_from_pdag <- function(pdag) {
    cp_session <- rs_to_cpdag(pdag@session)
    .session_to_caugi(cp_session, node_names = nodes(pdag)$name)
  }
  edge_set <- function(g) {
    ed <- edges(g)
    sort(paste(ed$from, ed$edge, ed$to))
  }

  # Case 1 (pgmpy test_pdag_to_cpdag): A->B and B-C => B->C
  pdag1 <- caugi(A %-->% B, B %---% C, class = "PDAG")
  cpdag1 <- cpdag_from_pdag(pdag1)
  expect_setequal(
    edge_set(cpdag1),
    edge_set(caugi(A %-->% B, B %-->% C, class = "PDAG"))
  )

  # Case 2: orientation propagates along B-C-D.
  pdag2 <- caugi(A %-->% B, B %---% C, C %---% D, class = "PDAG")
  cpdag2 <- cpdag_from_pdag(pdag2)
  expect_setequal(
    edge_set(cpdag2),
    edge_set(caugi(A %-->% B, B %-->% C, C %-->% D, class = "PDAG"))
  )

  # Case 3 (pgmpy fixture): keep B-C undirected.
  pdag3 <- caugi(A %-->% B, D %-->% C, B %---% C, class = "PDAG")
  cpdag3 <- cpdag_from_pdag(pdag3)
  expect_setequal(
    edge_set(cpdag3),
    edge_set(pdag3)
  )

  # Case 4 (pgmpy fixture): extra parent evidence orients B->C.
  pdag4 <- caugi(
    A %-->% B,
    D %-->% C,
    D %-->% B,
    B %---% C,
    class = "PDAG"
  )
  cpdag4 <- cpdag_from_pdag(pdag4)
  expect_setequal(
    edge_set(cpdag4),
    edge_set(caugi(A %-->% B, D %-->% C, D %-->% B, B %-->% C, class = "PDAG"))
  )

  # Case 5 (rule-2 style): A->B->C and A-C => A->C.
  pdag5 <- caugi(A %-->% B, B %-->% C, A %---% C, class = "PDAG")
  cpdag5 <- cpdag_from_pdag(pdag5)
  expect_setequal(
    edge_set(cpdag5),
    edge_set(caugi(A %-->% B, B %-->% C, A %-->% C, class = "PDAG"))
  )
})

test_that("condition_marginalize and helper branches are covered", {
  cg_ug <- caugi(A %o->% B, class = "UNKNOWN")
  expect_error(
    condition_marginalize(cg_ug, cond_vars = "A"),
    "`cg` must be an AG for `condition_marginalize\\(\\)`"
  )

  cg <- caugi(A %-->% B, class = "DAG")
  out_trivial <- condition_marginalize(cg, marg_vars = "B")
  expect_equal(out_trivial@graph_class, "AG")
  expect_setequal(out_trivial@nodes$name, "A")

  # Force non-list anteriors branch (line coverage via expected error).
  cg2 <- caugi(A %-->% B %-->% C, class = "DAG")
  expect_error(
    testthat::with_mocked_bindings(
      condition_marginalize(cg2, cond_vars = "B"),
      anteriors = function(...) "A",
      .package = "caugi"
    ),
    "must be the same length"
  )

  expect_type(
    caugi:::.not_m_separated_for_all_subsets(
      cg = cg2,
      node_a = "A",
      node_b = "C",
      other_nodes = character(0),
      cond_vars = character(0)
    ),
    "logical"
  )

  edge_rev <- caugi:::.edge_type_from_anteriors(
    node_a = "A",
    node_b = "B",
    cond_vars = character(0),
    anteriors_list = list(A = "B", B = NULL)
  )
  expect_identical(edge_rev$from, "B")
  expect_identical(edge_rev$edge, "-->")
  expect_identical(edge_rev$to, "A")
})
