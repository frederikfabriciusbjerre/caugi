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
