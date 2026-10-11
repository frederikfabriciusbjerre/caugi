test_that("components includes empty graphs and isolated nodes", {
  for (mode in c("weak", "strong")) {
    expect_identical(components(caugi(), mode), list())
    expect_identical(components(caugi(A), mode), list("A"))
    expect_identical(
      components(caugi(nodes = c("Z", "A", "M")), mode),
      list("Z", "A", "M")
    )
  }
})

test_that("weak components ignore direction and follow node order", {
  cg <- caugi(
    A %-->% B,
    C %-->% B,
    E %-->% F,
    D,
    nodes = c("F", "C", "D", "B", "E", "A"),
    class = "DAG"
  )
  expect_identical(components(cg), list(c("F", "E"), c("C", "B", "A"), "D"))
  expect_identical(components(cg, "strong"), as.list(nodes(cg)$name))
})

test_that("strong components separate cycles joined by one-way edges", {
  cg <- caugi(
    A %-->% C,
    C %-->% E,
    E %-->% A,
    E %-->% B,
    B %-->% D,
    D %-->% F,
    F %-->% B,
    G,
    nodes = LETTERS[1:7],
    class = "UNKNOWN"
  )
  expect_identical(
    components(cg, "strong"),
    list(c("A", "C", "E"), c("B", "D", "F"), "G")
  )
  expect_identical(components(cg), list(LETTERS[1:6], "G"))
})

test_that("mixed edges connect weakly but do not imply directed reachability", {
  cg <- caugi(
    A %-->% B,
    B %-->% C,
    C %-->% A,
    C %---% D,
    D %<->% E,
    E %o->% F,
    F %--o% G,
    G %o-o% H,
    nodes = LETTERS[1:8],
    class = "UNKNOWN"
  )
  expect_identical(components(cg), list(LETTERS[1:8]))
  expect_identical(
    components(cg, "strong"),
    c(list(LETTERS[1:3]), as.list(LETTERS[4:8]))
  )

  ug <- caugi(A %---% B, C, class = "UG")
  expect_identical(components(ug), list(c("A", "B"), "C"))
  expect_identical(components(ug, "strong"), list("A", "B", "C"))

  admg <- caugi(A %<->% B, B %-->% C, class = "ADMG")
  expect_identical(components(admg), list(c("A", "B", "C")))
  expect_identical(components(admg, "strong"), list("A", "B", "C"))
})

test_that("components rebuilds after lazy mutations", {
  cg <- caugi(A %-->% B, C, class = "UNKNOWN")
  build(cg)
  cg <- add_edges(cg, B %-->% C, C %-->% A)
  expect_false(rs_is_valid(cg@session)$view_valid)
  expect_identical(components(cg, "strong"), list(c("A", "B", "C")))
  expect_true(rs_is_valid(cg@session)$core_valid)

  cg <- remove_edges(cg, C %-->% A, B %-->% C)
  expect_identical(components(cg), list(c("A", "B"), "C"))
  expect_identical(components(cg, "strong"), list("A", "B", "C"))
})

test_that("components handles self-loops and parallel edge types", {
  cg <- caugi(
    A %-->% A,
    A %-->% B,
    A %<->% B,
    B %-->% A,
    C,
    class = "UNKNOWN",
    simple = FALSE
  )
  for (mode in c("weak", "strong")) {
    expect_identical(components(cg, mode), list(c("A", "B"), "C"))
  }
})

test_that("components validates inputs and accepts abbreviated modes", {
  expect_error(components(list()), "Input must be a caugi")
  cg <- caugi(A %-->% B)
  for (mode in list(
    "other",
    NA_character_,
    character(),
    1,
    c("weak", "strong", "other")
  )) {
    expect_error(components(cg, mode))
  }
  expect_identical(components(cg, "w"), components(cg, "weak"))
  expect_identical(components(cg, "s"), components(cg, "strong"))
})

test_that("directed component partitions agree with igraph", {
  skip_if_not_installed("igraph")
  set.seed(47)
  for (n in c(1L, 8L, 20L)) {
    for (prob in c(0, 0.1, 0.4)) {
      adj <- matrix(rbinom(n * n, 1, prob), n, n)
      diag(adj) <- 0
      node_names <- paste0("V", seq_len(n))
      dimnames(adj) <- list(node_names, node_names)
      edge_index <- which(adj != 0, arr.ind = TRUE)
      cg <- caugi(
        from = node_names[edge_index[, 1]],
        edge = rep("-->", nrow(edge_index)),
        to = node_names[edge_index[, 2]],
        nodes = node_names,
        class = "UNKNOWN",
        simple = FALSE
      )
      ig <- igraph::graph_from_adjacency_matrix(adj, mode = "directed")
      for (mode in c("weak", "strong")) {
        membership <- igraph::components(ig, mode = mode)$membership
        expected <- lapply(unique(membership), function(id) {
          node_names[membership == id]
        })
        expect_identical(components(cg, mode), expected)
      }
    }
  }
})
