# Tests for AG (Ancestral Graph) functionality

# ─────────────────────────────────────────────────────────────────────────────
# AG Construction and Validation
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_ag correctly identifies ancestral graphs", {
  # Pure DAG is a valid AG
  dag <- caugi(A %-->% B %-->% C, class = "DAG")
  expect_true(is_ag(dag, force_check = TRUE))

  # UG is a valid AG
  ug <- caugi(A %---% B, class = "UG")
  expect_true(is_ag(ug, force_check = TRUE))

  # ADMG is a valid AG (no undirected edges)
  admg <- caugi(
    A %-->% B,
    A %<->% C,
    class = "ADMG"
  )
  expect_true(is_ag(admg, force_check = TRUE))

  # AG with all three edge types (valid configuration)
  # Note: can't mix undirected edges with arrowhead edges on same node
  ag <- caugi(
    A %-->% B,
    C %<->% D,
    E %---% F,
    class = "AG"
  )
  expect_true(is_ag(ag))
  expect_equal(ag@graph_class, "AG")
})

test_that("AG rejects directed cycles", {
  expect_error(
    caugi(
      A %-->% B,
      B %-->% C,
      C %-->% A,
      class = "AG"
    ),
    regexp = "[Cc]ycle"
  )
})

test_that("AG rejects undirected constraint violation", {
  # A node with undirected edge cannot have arrowhead edge
  expect_error(
    caugi(
      A %---% B, # B has undirected edge
      C %-->% B, # B has incoming directed edge (arrowhead)
      class = "AG"
    ),
    regexp = "[Uu]ndirected"
  )

  expect_error(
    caugi(
      A %---% B, # B has undirected edge
      B %<->% C, # B has bidirected edge (arrowhead)
      class = "AG"
    ),
    regexp = "[Uu]ndirected"
  )
})

test_that("AG rejects partial edges", {
  expect_error(
    caugi(
      A %o->% B,
      class = "AG"
    ),
    regexp = "can only contain"
  )
})

# ─────────────────────────────────────────────────────────────────────────────
# Graph Query Functions
# ─────────────────────────────────────────────────────────────────────────────

test_that("parents and children work for AG", {
  ag <- caugi(
    A %-->% B,
    B %-->% C,
    D %<->% E,
    class = "AG"
  )

  expect_equal(parents(ag, "B"), "A")
  expect_equal(children(ag, "A"), "B")
  expect_equal(parents(ag, "C"), "B")
  expect_equal(children(ag, "B"), "C")
})

test_that("spouses works for AG", {
  ag <- caugi(
    A %-->% B,
    C %<->% D,
    class = "AG"
  )

  expect_equal(spouses(ag, "C"), "D")
  expect_equal(spouses(ag, "D"), "C")
  expect_equal(length(spouses(ag, "A")), 0L)
})

test_that("undirected neighbors work for AG", {
  ag <- caugi(
    A %---% B %---% C,
    class = "AG"
  )

  expect_equal(neighbors(ag, "B", mode = "undirected"), c("A", "C"))
  expect_equal(neighbors(ag, "A", mode = "undirected"), "B")
})

test_that("ancestors and descendants work for AG", {
  ag <- caugi(
    A %-->% B %-->% C,
    D %<->% E,
    class = "AG"
  )

  expect_equal(sort(ancestors(ag, "C")), c("A", "B"))
  expect_equal(sort(descendants(ag, "A")), c("B", "C"))

  # Bidirected doesn't count as ancestor/descendant
  expect_equal(length(ancestors(ag, "D")), 0L)
  expect_equal(length(descendants(ag, "D")), 0L)
})

test_that("anteriors work for AG", {
  # Anteriors include parents and undirected neighbors transitively
  # Note: In an AG, a node with undirected edge can't have arrowhead edges
  # So we create a valid graph: A --> B, C --- D --- E
  ag <- caugi(
    A %-->% B,
    C %---% D %---% E,
    class = "AG"
  )

  # Anteriors of B: A (parent)
  ant_b <- anteriors(ag, "B")
  expect_true("A" %in% ant_b)

  # Anteriors of E: D (undirected), C (via D)
  ant_e <- anteriors(ag, "E")
  expect_true("D" %in% ant_e)
  expect_true("C" %in% ant_e) # via D --- C
})

test_that("posteriors work for AG", {
  # Posteriors include children and undirected neighbors transitively
  # Note: In an AG, a node with undirected edge can't have arrowhead edges
  # So we create a valid graph: A --> B, C --- D --- E
  ag <- caugi(
    A %-->% B,
    C %---% D %---% E,
    class = "AG"
  )

  # Posteriors of A: B (child)
  post_a <- posteriors(ag, "A")
  expect_true("B" %in% post_a)

  # Posteriors of C: D (undirected), E (via D)
  post_c <- posteriors(ag, "C")
  expect_true("D" %in% post_c)
  expect_true("E" %in% post_c) # via D --- E
})

test_that("exogenous returns nodes without parents", {
  ag <- caugi(
    A %-->% B,
    C %<->% D,
    E %---% F,
    class = "AG"
  )

  exo <- exogenous(ag)

  # A, C, D, E, F have no parents
  expect_true("A" %in% exo)
  expect_true("C" %in% exo)
  expect_true("D" %in% exo)
  expect_true("E" %in% exo)
  expect_true("F" %in% exo)
  expect_false("B" %in% exo)
})

# ─────────────────────────────────────────────────────────────────────────────
# M-Separation
# ─────────────────────────────────────────────────────────────────────────────

test_that("m_separated works for chain structures in AG", {
  ag <- caugi(
    A %-->% B %-->% C,
    class = "AG"
  )

  # A and C not separated unconditionally
  expect_false(m_separated(ag, X = "A", Y = "C"))

  # A and C separated given B
  expect_true(m_separated(ag, X = "A", Y = "C", Z = "B"))
})

test_that("m_separated works for collider structures in AG", {
  ag <- caugi(
    A %-->% C,
    B %-->% C,
    class = "AG"
  )

  # A and B are m-separated unconditionally (collider at C blocks)
  expect_true(m_separated(ag, X = "A", Y = "B"))

  # A and B NOT m-separated given C (conditioning on collider opens)
  expect_false(m_separated(ag, X = "A", Y = "B", Z = "C"))
})

test_that("m_separated works for undirected paths in AG", {
  ag <- caugi(
    A %---% B %---% C,
    class = "AG"
  )

  # A and C not m-separated unconditionally (connected via undirected)
  expect_false(m_separated(ag, X = "A", Y = "C"))

  # A and C m-separated given B
  expect_true(m_separated(ag, X = "A", Y = "C", Z = "B"))
})

test_that("m_separated blocks a mixed path when conditioning on undirected bridge", {
  ag <- caugi(
    `1` %-->% `4`,
    `2` %-->% `4`,
    `2` %-->% `3`,
    `3` %-->% `5`,
    `4` %-->% `5`,
    `1` %-->% `3`,
    `1` %---% `6`,
    `6` %---% `2`,
    class = "AG"
  )

  expect_false(m_separated(ag, X = "1", Y = "2"))
  expect_true(m_separated(ag, X = "1", Y = "2", Z = "6"))
})

test_that("m_separated handles bidirected confounding in AG", {
  ag <- caugi(
    A %-->% B,
    C %<->% D,
    class = "AG"
  )

  # C and D are not m-separated (directly connected via bidirected)
  expect_false(m_separated(ag, X = "C", Y = "D"))

  # A and C are m-separated (no path)
  expect_true(m_separated(ag, X = "A", Y = "C"))
})

test_that("m_separated opens collider paths in bidirected chains", {
  ag <- caugi(
    A %<->% B %<->% C %<->% D,
    class = "AG"
  )

  # Colliders block the path unless conditioned on.
  expect_true(m_separated(ag, X = "A", Y = "D"))

  # Conditioning on colliders opens the path.
  expect_false(m_separated(ag, X = "A", Y = "D", Z = c("B", "C")))
})

# ─────────────────────────────────────────────────────────────────────────────
# Districts
# ─────────────────────────────────────────────────────────────────────────────

test_that("districts returns c-components for AG", {
  ag <- caugi(
    A %-->% B,
    C %<->% D,
    E %---% F,
    class = "AG"
  )

  dists <- districts(ag)

  # Should have districts: {C,D} and singletons for A, B, E, F
  expect_equal(length(dists), 5L)

  # Check that C and D are in the same district
  c_dist <- dists[sapply(dists, function(d) "C" %in% d)][[1]]
  expect_true("D" %in% c_dist)
})

# ─────────────────────────────────────────────────────────────────────────────
# MAG (Maximal Ancestral Graph) - Basic Structures
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_mag correctly identifies chain structure as MAG", {
  # Chain: A -> B -> C
  # A and C are m-separated by {B}, so this is a MAG
  ag_chain <- caugi(
    A %-->% B %-->% C,
    class = "AG"
  )

  expect_true(is_mag(ag_chain))
})

test_that("is_mag correctly identifies fork structure as MAG", {
  # Fork: B <- A -> C
  # B and C are m-separated by {A}, so this is a MAG
  ag_fork <- caugi(
    A %-->% B,
    A %-->% C,
    class = "AG"
  )

  expect_true(is_mag(ag_fork))
})

test_that("is_mag correctly identifies collider structure as MAG", {
  # Collider: A -> C <- B
  # A and B are m-separated by empty set (collider blocks), so this is a MAG
  ag_collider <- caugi(
    A %-->% C,
    B %-->% C,
    class = "AG"
  )

  expect_true(is_mag(ag_collider))
})

test_that("is_mag correctly identifies complete graph as MAG", {
  # Complete graph: all pairs adjacent
  # Trivially maximal (no non-adjacent pairs to check)
  ag_complete <- caugi(
    A %-->% B,
    A %-->% C,
    B %<->% C,
    class = "AG"
  )

  expect_true(is_mag(ag_complete))
})

# ─────────────────────────────────────────────────────────────────────────────
# MAG - Mixed Edge Types
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_mag works with directed and bidirected edges", {
  # Directed + bidirected in separate components
  ag_mixed <- caugi(
    A %-->% B,
    C %<->% D,
    class = "AG"
  )

  # A,B adjacent; C,D adjacent; all other pairs have no path -> m-separated by {}

  expect_true(is_mag(ag_mixed))
})

test_that("is_mag works with undirected chain", {
  # Undirected chain: A --- B --- C
  # A and C m-separated by {B}
  ag_undirected <- caugi(
    A %---% B %---% C,
    class = "AG"
  )

  expect_true(is_mag(ag_undirected))
})

test_that("is_mag works with complex mixed edge types", {
  # Mixed graph with all three edge types (in valid AG configuration)
  # Note: nodes with undirected edges can't have arrowhead edges
  ag_complex <- caugi(
    A %-->% B,
    C %<->% D,
    E %---% F,
    class = "AG"
  )

  # All non-adjacent pairs are in different components -> m-separated by {}
  expect_true(is_mag(ag_complex))
})

test_that("is_mag works with bidirected chain (collider structure)", {
  # Bidirected chain: A <-> B <-> C <-> D
  # Each internal node is a collider, blocking paths
  ag_bid_chain <- caugi(
    A %<->% B %<->% C %<->% D,
    class = "AG"
  )

  # A and D are m-separated by {} (colliders at B and C block the path)
  expect_true(is_mag(ag_bid_chain))
})

# ─────────────────────────────────────────────────────────────────────────────
# MAG - Edge Cases
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_mag handles single node graph", {
  # Single node is trivially a MAG (no pairs to check)
  ag_single <- caugi(A, class = "AG")

  expect_true(is_mag(ag_single))
})

test_that("is_mag handles two disconnected nodes", {
  # Two nodes with no edges
  # They are m-separated by empty set (no path between them)
  ag_disconnected <- caugi(A, B, class = "AG")

  expect_true(is_mag(ag_disconnected))
})

test_that("is_mag handles multiple disconnected components", {
  # Multiple components: A->B, C->D, E (isolated)
  # All cross-component pairs have no path -> m-separated by {}
  ag_multi_comp <- caugi(
    A %-->% B,
    C %-->% D,
    E,
    class = "AG"
  )

  expect_true(is_mag(ag_multi_comp))
})

test_that("is_mag handles larger disconnected components", {
  # Two chains in separate components
  ag_two_chains <- caugi(
    A %-->% B %-->% C,
    D %-->% E %-->% F,
    class = "AG"
  )

  # Within each chain: non-adjacent pairs m-separated by middle node
  # Across chains: no path -> m-separated by {}
  expect_true(is_mag(ag_two_chains))
})

# ─────────────────────────────────────────────────────────────────────────────
# MAG - force_check Parameter
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_mag respects force_check parameter", {
  # Create a graph that we know is a MAG
  ag <- caugi(
    A %-->% B %-->% C,
    class = "AG"
  )

  # Both with and without force_check should return TRUE for a valid MAG
  expect_true(is_mag(ag, force_check = FALSE))
  expect_true(is_mag(ag, force_check = TRUE))
})

test_that("is_mag returns TRUE for AG class without check when force_check=FALSE", {
  # An AG-classed graph should be checked by default
  ag <- caugi(
    A %-->% B,
    class = "AG"
  )

  result <- is_mag(ag, force_check = FALSE)
  expect_true(result)
})

# ─────────────────────────────────────────────────────────────────────────────
# MAG - Non-AG Graphs
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_mag works with DAG (valid AG)", {
  # A DAG is a valid AG, so is_mag should work
  dag <- caugi(
    A %-->% B %-->% C,
    class = "DAG"
  )

  # DAG chain is a MAG (A,C m-separated by B)
  expect_true(is_mag(dag, force_check = TRUE))
})

test_that("is_mag works with ADMG (valid AG)", {
  # An ADMG is a valid AG - use a structure that is actually a MAG
  # Chain structure where non-adjacent nodes are m-separated
  admg <- caugi(
    A %-->% B %-->% C,
    class = "ADMG"
  )

  # A and C are m-separated by B
  expect_true(is_mag(admg, force_check = TRUE))
})

test_that("is_mag works with UG (valid AG)", {
  # A UG is a valid AG
  ug <- caugi(
    A %---% B %---% C,
    class = "UG"
  )

  expect_true(is_mag(ug, force_check = TRUE))
})

test_that("is_mag returns FALSE for PDAG", {
  # PDAG is not an AG type - is_mag should return FALSE
  pdag <- caugi(
    A %-->% B,
    B %---% C,
    class = "PDAG"
  )

  # PDAG is not a valid AG structure for MAG checking
  expect_false(is_mag(pdag, force_check = TRUE))
})

# ─────────────────────────────────────────────────────────────────────────────
# MAG - Larger Graph Structures
# ─────────────────────────────────────────────────────────────────────────────

test_that("is_mag handles diamond structure", {
  # Diamond: A -> B, A -> C, B -> D, C -> D
  ag_diamond <- caugi(
    A %-->% B,
    A %-->% C,
    B %-->% D,
    C %-->% D,
    class = "AG"
  )

  # B and C: paths B <- A -> C (fork at A, m-separated by {A})
  #          and B -> D <- C (collider at D, m-separated by {})
  # So B and C are m-separated by {} or {A}
  expect_true(is_mag(ag_diamond))
})

test_that("is_mag handles M-structure", {
  # M-structure: A <- B -> C, C <- D -> E
  ag_m <- caugi(
    B %-->% A,
    B %-->% C,
    D %-->% C,
    D %-->% E,
    class = "AG"
  )

  # A and E: path A <- B -> C <- D -> E
  # B is non-collider, C is collider (from B and D)
  # Collider at C blocks -> A and E m-separated by {}
  expect_true(is_mag(ag_m))
})

test_that("is_mag handles longer chain", {
  # Chain with 5 nodes: A -> B -> C -> D -> E
  ag_long_chain <- caugi(
    A %-->% B %-->% C %-->% D %-->% E,
    class = "AG"
  )

  # All non-adjacent pairs can be m-separated by intermediate nodes
  expect_true(is_mag(ag_long_chain))
})

test_that("is_mag handles tree structure", {
  # Tree: A -> B, A -> C, B -> D, B -> E, C -> F
  ag_tree <- caugi(
    A %-->% B,
    A %-->% C,
    B %-->% D,
    B %-->% E,
    C %-->% F,
    class = "AG"
  )

  # All non-adjacent pairs can be separated by appropriate ancestors
  expect_true(is_mag(ag_tree))
})

test_that("is_mag handles butterfly structure with bidirected", {
  # Butterfly: A -> C <- B and A <-> B (latent common cause)
  ag_butterfly <- caugi(
    A %-->% C,
    B %-->% C,
    A %<->% B,
    class = "AG"
  )

  # A and B are adjacent via bidirected edge
  # All pairs adjacent -> trivially MAG
  expect_true(is_mag(ag_butterfly))
})

test_that("is_mag handles bidirected confounding structure", {
  # Confounding with bidirected: A <-> B, C <-> D (separate components)
  ag_confounded <- caugi(
    A %<->% B,
    C %<->% D,
    class = "AG"
  )

  # A,B adjacent; C,D adjacent
  # Cross-component pairs (A,C), (A,D), (B,C), (B,D) have no path
  # -> all m-separated by empty set
  expect_true(is_mag(ag_confounded))
})

test_that("is_mag handles mediated confounding structure", {
  # Structure: X -> M -> Y, with separate confounder U <-> Y
  ag_mediated <- caugi(
    X %-->% M,
    M %-->% Y,
    U %<->% Y,
    class = "AG"
  )

  # X and U are non-adjacent but have no path between them
  # -> m-separated by empty set
  expect_true(is_mag(ag_mediated))
})

# ─────────────────────────────────────────────────────────────────────────────
# Markov Blanket
# ─────────────────────────────────────────────────────────────────────────────

test_that("markov_blanket works for AG", {
  ag <- caugi(
    L %-->% X,
    X %-->% Y,
    X %<->% Z,
    class = "AG"
  )

  mb_x <- markov_blanket(ag, "X")

  # MB(X) includes parents, and district members (spouses)
  expect_true("L" %in% mb_x) # Parent of X
  expect_true("Z" %in% mb_x) # Spouse (district member)
})

# ─────────────────────────────────────────────────────────────────────────────
# Subgraph
# ─────────────────────────────────────────────────────────────────────────────

test_that("subgraph preserves AG class", {
  ag <- caugi(
    A %-->% B %-->% C,
    D %<->% E,
    class = "AG"
  )

  sub <- subgraph(ag, c("A", "B", "C"))

  expect_equal(sub@graph_class, "AG")
  expect_true(is_ag(sub))
})
