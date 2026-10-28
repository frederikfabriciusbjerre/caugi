# example seen in Elements of Causal Inference, Figure 6.5, p. 115
adjustment_set_cg <- caugi(
  C %-->% X,
  X %-->% F,
  X %-->% D,
  A %-->% X,
  A %-->% K,
  K %-->% Y,
  D %-->% Y,
  D %-->% G,
  Y %-->% H,
  class = "DAG"
)

test_that("d-separation checks", {
  expect_false(d_separated(adjustment_set_cg, "X", "Y")) # backdoor via A-->K-->Y and causal X-->D-->Y
  expect_false(d_separated(adjustment_set_cg, "X", "Y", Z = "A")) # causal path still open
  expect_false(d_separated(adjustment_set_cg, "X", "Y", Z = "K")) # causal path still open
  expect_false(d_separated(adjustment_set_cg, "X", "Y", Z = "D")) # backdoor still open
  expect_true(d_separated(adjustment_set_cg, "X", "Y", Z = c("A", "D"))) # backdoor and causal both blocked
  expect_true(d_separated(adjustment_set_cg, "X", "Y", Z = c("K", "D"))) # backdoor and causal both blocked

  # now with indexes
  expect_false(d_separated(adjustment_set_cg, X_index = 2L, Y_index = 6L)) # backdoor via A-->K-->Y and causal X-->D-->Y
  expect_false(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = 3L
  )) # causal path still open
  expect_false(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = 4L
  )) # causal path still open
  expect_false(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = 5L
  )) # backdoor still open
  expect_true(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = c(3L, 5L)
  ))
  expect_true(d_separated(
    adjustment_set_cg,
    X_index = 2L,
    Y_index = 6L,
    Z_index = c(4L, 5L)
  ))
})

test_that("adjustment_set(type = 'parents') returns Pa(X) \\ {X,Y}", {
  got <- adjustment_set(adjustment_set_cg, "X", "Y", type = "parents")
  expect_setequal(got, c("A", "C"))
})

test_that("adjustment_set(type = 'backdoor') returns a valid backdoor set", {
  Z <- adjustment_set(adjustment_set_cg, "X", "Y", type = "backdoor")
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = Z))
  expect_false("D" %in% Z) # descendant of X should not appear
})

test_that("adjustment_set(type = 'backdoor') blocks paths via non-An(Y) parents (#308)", {
  cg <- caugi(C %-->% B %-->% X, C %-->% Y, class = "DAG")
  Z <- adjustment_set(cg, "X", "Y", type = "backdoor")
  expect_true(is_valid_backdoor(cg, X = "X", Y = "Y", Z = Z))
  # B is a parent of X, not an ancestor of Y, yet it blocks X <- B <- C -> Y.
  # The minimal set is a single node, either {B} or {C}.
  expect_length(Z, 1L)
  expect_true(setequal(Z, "B") || setequal(Z, "C"))
})

test_that("adjustment_set(type = 'backdoor') returns a minimal (not parent) set", {
  # With no backdoor path the minimal set is empty, while `parents` still
  # conditions on every parent of X.
  cg <- caugi(A %-->% X, X %-->% Y, B %-->% X, class = "DAG")
  Z <- adjustment_set(cg, "X", "Y", type = "backdoor")
  expect_length(Z, 0L)
  expect_true(is_valid_backdoor(cg, X = "X", Y = "Y", Z = NULL))
  expect_setequal(adjustment_set(cg, "X", "Y", type = "parents"), c("A", "B"))
})

test_that("adjustment_set(type = 'optimal') is valid and minimal here", {
  Z <- adjustment_set(adjustment_set_cg, "X", "Y", type = "optimal")
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = Z))
  expect_true(setequal(Z, "A") || setequal(Z, "K")) # minimal sets in this DAG
})

test_that("is_valid_backdoor works on canonical choices", {
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = "A"))
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = "K"))
  expect_false(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = "D"))
  expect_false(is_valid_backdoor(
    adjustment_set_cg,
    X = "X",
    Y = "Y",
    Z = c("A", "D")
  ))
  expect_false(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = NULL))
})

test_that("all_backdoor_sets enumerates minimal sets", {
  sets <- all_backdoor_sets(adjustment_set_cg, X = "X", Y = "Y")
  norm <- lapply(sets, sort)
  expect_equal(length(norm), 2L)
  expect_true(any(setequal(norm[[1]], "A") | setequal(norm[[2]], "A")))
  expect_true(any(setequal(norm[[1]], "K") | setequal(norm[[2]], "K")))
})

test_that("all_backdoor_sets respects max_size and minimal", {
  sets <- all_backdoor_sets(adjustment_set_cg, X = "X", Y = "Y", minimal = TRUE)
  expect_equal(length(sets), 2L)
  expect_setequal(sets, c("A", "K"))
  sets2 <- all_backdoor_sets(
    adjustment_set_cg,
    X = "X",
    Y = "Y",
    minimal = FALSE,
    max_size = 2
  )
  expect_equal(length(sets2), 5L)
  expect_setequal(sets2, list("A", "K", c("A", "K"), c("C", "A"), c("C", "K")))
})

test_that("all_backdoor_sets includes empty set, if valid", {
  adjustment_set_cg <- caugi(
    C %-->% X,
    X %-->% F,
    X %-->% D,
    A %-->% X,
    A %-->% L, # add v structure, now empty set is valid
    K %-->% L,
    K %-->% Y,
    D %-->% Y,
    D %-->% G,
    Y %-->% H,
    class = "DAG"
  )
  # check if empty set is valid
  expect_true(is_valid_backdoor(adjustment_set_cg, X = "X", Y = "Y", Z = NULL))

  sets <- all_backdoor_sets(
    adjustment_set_cg,
    X = "X",
    Y = "Y",
    minimal = FALSE,
    max_size = 2
  )
  valid_sets <- list(
    character(0),
    "C",
    "A",
    "K",
    c("A", "K"),
    c("C", "A"),
    c("C", "K"),
    c("A", "L"),
    c("K", "L")
  )
  expect_setequal(sets, valid_sets)
})

test_that("backdoor and d-separation functions cannot take multiple inputs", {
  expect_error(
    is_valid_backdoor(adjustment_set_cg, X = "X", Y = c("Y", "D"), Z = "A"),
    "Provide exactly one X and one Y."
  )
  expect_error(
    all_backdoor_sets(adjustment_set_cg, X = "X", Y = c("Y", "D")),
    "Provide exactly one X and one Y."
  )
  expect_error(
    d_separated(adjustment_set_cg, X_index = c(1L, 2L), Y = "Y", Z = "A"),
    "Provide exactly one X and one Y."
  )
})

test_that("adjust functions fails with faulty input", {
  expect_error(
    adjustment_set(adjustment_set_cg, X = "X", Y = NULL, type = "parents"),
    "Y \\(or Y_index\\) must be provided"
  )
  expect_error(
    adjustment_set(adjustment_set_cg, X = c("X", "Y"), Y = "Y"),
    "X and Y must be disjoint"
  )
  for (type in c("optimal", "parents", "backdoor")) {
    expect_error(
      adjustment_set(adjustment_set_cg, X = character(0), Y = "Y", type = type),
      "`X` must name at least one node"
    )
    expect_error(
      adjustment_set(adjustment_set_cg, X = "X", Y = character(0), type = type),
      "`Y` must name at least one node"
    )
  }
  expect_error(
    adjustment_set(adjustment_set_cg, X = "X", Y_index = integer(0)),
    "`Y` must name at least one node"
  )
  expect_error(
    adjustment_set(
      adjustment_set_cg,
      X = "X",
      Y = "Y",
      Y_index = 6L,
      type = "parent"
    ),
    "Provide either a node name or node index"
  )
  expect_error(
    d_separated(adjustment_set_cg, X = "X", Y = "Y", Z = "A", Z_index = 3L),
    "Provide either a node name or node index"
  )
})

test_that("mediator-only graph keeps empty adjustment set and rejects mediator", {
  cg <- caugi(
    X %-->% M,
    M %-->% Y,
    Y %-->% S,
    class = "DAG"
  )

  expect_true(is_valid_backdoor(cg, X = "X", Y = "Y", Z = NULL))
  expect_false(is_valid_backdoor(cg, X = "X", Y = "Y", Z = "M"))

  sets <- all_backdoor_sets(cg, X = "X", Y = "Y", minimal = TRUE, max_size = 1L)
  expect_equal(sets, list(character(0)))
})

test_that("collider-driven adjustment candidates are validated consistently", {
  cg <- caugi(
    A %-->% Z,
    B %-->% Z,
    A %-->% X,
    B %-->% Y,
    class = "DAG"
  )

  expect_false(is_valid_backdoor(cg, X = "X", Y = "Y", Z = "Z"))
  expect_true(is_valid_backdoor(cg, X = "X", Y = "Y", Z = "A"))
  expect_true(is_valid_backdoor(cg, X = "X", Y = "Y", Z = c("A", "Z")))
  expect_true(is_valid_backdoor(cg, X = "X", Y = "Y", Z = c("B", "Z")))

  sets <- all_backdoor_sets(
    cg,
    X = "X",
    Y = "Y",
    minimal = FALSE,
    max_size = 2L
  )
  set_strings <- vapply(
    sets,
    function(z) paste(sort(z), collapse = ","),
    character(1)
  )
  expect_true("" %in% set_strings)
  expect_true("A,Z" %in% set_strings)
  expect_true("B,Z" %in% set_strings)
})

# Generalized adjustment criterion (Perković et al. 2018) straight from its
# definition: enumerate every path from X to Y, so it shares no code with the
# Rust implementation (masks, proper backdoor graph, moralisation).
.gac_oracle <- function(edges, X, Y) {
  dir <- edges[edges$edge == "-->", ]
  closure <- function(seeds, step) {
    out <- seeds
    repeat {
      nxt <- union(out, step(out))
      if (length(nxt) == length(out)) {
        return(out)
      }
      out <- nxt
    }
  }
  an <- function(s) closure(s, function(v) dir$from[dir$to %in% v])
  de <- function(s) closure(s, function(v) dir$to[dir$from %in% v])
  # arrowhead of edge i at node v
  head_at <- function(i, v) {
    edges$edge[i] == "<->" || edges$to[i] == v
  }

  # All proper paths (only the first node in X) from X to Y, as lists of
  # node and edge index sequences.
  paths <- list()
  walk <- function(path, used) {
    v <- path[length(path)]
    if (length(path) > 1 && v %in% Y) {
      paths[[length(paths) + 1]] <<- list(nodes = path, edges = used)
    }
    for (i in which(edges$from == v | edges$to == v)) {
      w <- if (edges$from[i] == v) edges$to[i] else edges$from[i]
      if (!w %in% path && !w %in% X) walk(c(path, w), c(used, i))
    }
  }
  for (x in X) {
    walk(x, integer(0))
  }

  is_causal <- vapply(
    paths,
    function(p) {
      all(edges$edge[p$edges] == "-->") &&
        all(edges$from[p$edges] == p$nodes[-length(p$nodes)])
    },
    logical(1)
  )
  cn <- unique(unlist(lapply(paths[is_causal], function(p) p$nodes[-1])))
  forb <- union(de(cn), X)

  function(Z) {
    if (any(Z %in% forb)) {
      return(FALSE)
    }
    an_z <- an(Z)
    for (p in paths[!is_causal]) {
      k <- length(p$nodes)
      open <- TRUE
      for (j in seq_len(k - 2) + 1) {
        v <- p$nodes[j]
        collider <- head_at(p$edges[j - 1], v) && head_at(p$edges[j], v)
        if (collider && !v %in% an_z || !collider && v %in% Z) {
          open <- FALSE
          break
        }
      }
      if (open) return(FALSE)
    }
    TRUE
  }
}

# Random edges on `nodes` in a random topological order. Each pair gets no
# edge, `-->`, `<->` or a bow (both), with probabilities `prob`.
.random_admg_edges <- function(nodes, prob = c(0.45, 0.3, 0.15, 0.1)) {
  ord <- sample(nodes)
  pairs <- t(combn(length(nodes), 2))
  kind <- sample(c("", "-->", "<->", "bow"), nrow(pairs), TRUE, prob)
  from <- ord[pairs[, 1]]
  to <- ord[pairs[, 2]]
  dir <- kind %in% c("-->", "bow")
  bi <- kind %in% c("<->", "bow")
  data.frame(
    from = c(from[dir], from[bi]),
    edge = rep(c("-->", "<->"), c(sum(dir), sum(bi))),
    to = c(to[dir], to[bi])
  )
}

# Ground truth from the definition of an adjustment set, with no graphical
# criterion. In a random binary model compatible with the graph (each `<->` is
# a latent common parent), returns for each Z the largest gap between
# P(y | do(x)) and sum_z P(y | x, z) P(z). Z is valid iff the gap is zero.
.exact_adjustment_gap <- function(edges, nodes, X, Y, Zs) {
  dir <- edges[edges$edge == "-->", ]
  bi <- edges[edges$edge == "<->", ]
  par <- setNames(lapply(nodes, function(v) dir$from[dir$to == v]), nodes)
  lat <- paste0("L", seq_len(nrow(bi)))
  for (i in seq_len(nrow(bi))) {
    par[[bi$from[i]]] <- c(par[[bi$from[i]]], lat[i])
    par[[bi$to[i]]] <- c(par[[bi$to[i]]], lat[i])
    par[[lat[i]]] <- character(0)
  }
  vars <- c(nodes, lat)
  S <- as.matrix(expand.grid(rep(list(0:1), length(vars))))
  colnames(S) <- vars
  code <- function(cols) {
    if (length(cols) == 0) {
      return(rep(0, nrow(S)))
    }
    drop(S[, cols, drop = FALSE] %*% 2^(seq_along(cols) - 1))
  }
  # P(v = s_v | parents) for every state s, from random conditional tables.
  fac <- vapply(
    vars,
    function(v) {
      p1 <- runif(2^length(par[[v]]), 0.05, 0.95)[code(par[[v]]) + 1]
      ifelse(S[, v] == 1, p1, 1 - p1)
    },
    numeric(nrow(S))
  )
  joint <- exp(rowSums(log(fac)))
  # Truncated factorisation: drop the factors of X.
  do_w <- exp(rowSums(log(fac[, setdiff(vars, X), drop = FALSE])))
  cx <- code(X)
  cy <- code(Y)
  p_do <- tapply(do_w, list(cx, cy), sum)
  vapply(
    Zs,
    function(Z) {
      cz <- code(Z)
      pxyz <- tapply(joint, list(cx, cy, cz), sum)
      pxz <- tapply(joint, list(cx, cz), sum)
      pz <- tapply(joint, cz, sum)
      adj <- p_do * 0
      for (k in seq_along(pz)) {
        adj <- adj + pxyz[,, k] / pxz[, k] * pz[k]
      }
      max(abs(adj - p_do))
    },
    numeric(1)
  )
}

test_that("ADMG adjustment with several treatments uses proper causal paths", {
  # W reaches Y only through the other treatment X2, so it is not causal.
  cg <- caugi(X1 %-->% W, W %-->% X2, X2 %-->% Y, class = "ADMG")
  expect_true(is_valid_adjustment_admg(cg, X = c("X1", "X2"), Y = "Y", Z = "W"))
  sets <- all_adjustment_sets_admg(
    cg,
    X = c("X1", "X2"),
    Y = "Y",
    minimal = FALSE
  )
  expect_setequal(lapply(sets, sort), list(character(0), "W"))

  # W is no longer forbidden, but it is still a collider on X1 --> W <-> Y,
  # while X2 <-- W <-> Y needs W: no valid set exists.
  cg <- caugi(
    X1 %-->% W,
    W %-->% X2,
    X2 %-->% Y,
    W %<->% Y,
    class = "ADMG"
  )
  expect_length(all_adjustment_sets_admg(cg, X = c("X1", "X2"), Y = "Y"), 0)
})

test_that("ADMG adjustment allows descendants of X off the causal paths", {
  # main forbade all of De(X) here, as X is an ancestor of Y.
  cg <- caugi(X %-->% Y + D, class = "ADMG")
  expect_true(is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = "D"))
  sets <- all_adjustment_sets_admg(cg, X = "X", Y = "Y", minimal = FALSE)
  expect_setequal(lapply(sets, sort), list(character(0), "D"))
})

test_that("ADMG adjustment forbids descendants of the outcome", {
  cg <- caugi(X %-->% Y, Y %-->% D, class = "ADMG")
  expect_false(is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = "D"))
  expect_true(is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = character(0)))
})

test_that("ADMG adjustment agrees with a brute-force oracle on random graphs", {
  set.seed(20261026)
  nodes <- paste0("V", 1:6)
  for (rep in seq_len(150)) {
    edges <- .random_admg_edges(nodes)
    cg <- caugi(
      from = edges$from,
      edge = edges$edge,
      to = edges$to,
      nodes = nodes,
      class = "ADMG",
      simple = FALSE
    )
    X <- sample(nodes, sample(1:2, 1))
    Y <- sample(setdiff(nodes, X), sample(1:2, 1))
    rest <- setdiff(nodes, c(X, Y))
    oracle <- .gac_oracle(edges, X, Y)

    subsets <- unlist(
      lapply(0:length(rest), function(k) combn(rest, k, simplify = FALSE)),
      recursive = FALSE
    )
    truth <- vapply(subsets, oracle, logical(1))
    got <- vapply(
      subsets,
      function(z) is_valid_adjustment_admg(cg, X = X, Y = Y, Z = z),
      logical(1)
    )
    expect_identical(got, truth, label = paste("rep", rep))

    all_sets <- all_adjustment_sets_admg(
      cg,
      X = X,
      Y = Y,
      minimal = FALSE,
      max_size = length(rest)
    )
    key <- function(z) paste(sort(z), collapse = ",")
    expect_setequal(
      vapply(all_sets, key, character(1)),
      vapply(subsets[truth], key, character(1))
    )
  }
})

test_that("adjustment_set() takes several treatments", {
  # W reaches Y only through X2, so it is not causal, but it is a collider on
  # X1 --> W <-- U --> Y: the parents of X ({W}) are not valid, {U} is.
  cg <- caugi(
    X1 %-->% W,
    W %-->% X2,
    X2 %-->% Y,
    U %-->% W + Y,
    class = "DAG"
  )
  X <- c("X1", "X2")
  expect_equal(adjustment_set(cg, X, "Y", type = "optimal"), "U")
  expect_equal(adjustment_set(cg, X, "Y", type = "backdoor"), "U")
  expect_error(
    adjustment_set(cg, X, "Y", type = "parents"),
    "parents of X are not a valid adjustment set"
  )
})

test_that("adjustment_set() errors when no valid set exists", {
  # Only L blocks X2 <-- L --> Y, but L is on the causal path X1 --> L --> Y.
  cg <- caugi(X1 %-->% L, L %-->% X2 + Y, X2 %-->% Y, class = "DAG")
  for (type in c("optimal", "parents", "backdoor")) {
    expect_error(
      adjustment_set(cg, c("X1", "X2"), "Y", type = type),
      "No valid adjustment set exists"
    )
  }
  # Y is a parent of X.
  expect_error(
    adjustment_set(
      caugi(Y %-->% X, class = "DAG"),
      "X",
      "Y",
      type = "backdoor"
    ),
    "No valid adjustment set exists"
  )
})

test_that("adjustment_set(type = 'optimal') drops Y not descending from X", {
  # Henckel, Perković & Maathuis (2022), Remark 3.14, as in pcalg::optAdjSet.
  cg <- caugi(U %-->% X + Y2, X %-->% Y1, class = "DAG")
  expect_warning(
    z <- adjustment_set(cg, "X", c("Y1", "Y2"), type = "optimal"),
    "dropped from Y.*Y2"
  )
  expect_equal(z, character(0))
  expect_error(
    adjustment_set(cg, "X", "Y2", type = "optimal"),
    "No node in Y is a descendant of X"
  )
  expect_equal(adjustment_set(cg, "X", c("Y1", "Y2"), type = "backdoor"), "U")

  # A dropped node can be in the O-set: Y2 is a parent of Y1.
  cg <- caugi(X %-->% Y1, Y2 %-->% Y1, class = "DAG")
  expect_warning(
    z <- adjustment_set(cg, "X", c("Y1", "Y2"), type = "optimal"),
    "dropped from Y.*Y2"
  )
  expect_equal(z, "Y2")
})

test_that("adjustment_set() agrees with a brute-force oracle on random DAGs", {
  set.seed(20261027)
  nodes <- paste0("V", 1:7)
  for (rep in seq_len(150)) {
    ord <- sample(nodes)
    pairs <- t(combn(7, 2))
    keep <- runif(nrow(pairs)) < 0.35
    edges <- data.frame(
      from = ord[pairs[keep, 1]],
      edge = rep("-->", sum(keep)),
      to = ord[pairs[keep, 2]]
    )
    cg <- caugi(
      from = edges$from,
      edge = edges$edge,
      to = edges$to,
      nodes = nodes,
      class = "DAG"
    )
    X <- sample(nodes, sample(1:2, 1))
    Y <- sample(setdiff(nodes, X), sample(1:2, 1))
    rest <- setdiff(nodes, c(X, Y))
    oracle <- .gac_oracle(edges, X, Y)
    subsets <- unlist(
      lapply(0:length(rest), function(k) combn(rest, k, simplify = FALSE)),
      recursive = FALSE
    )
    any_valid <- any(vapply(subsets, oracle, logical(1)))
    de_x <- X
    repeat {
      nxt <- union(de_x, edges$to[edges$from %in% de_x])
      if (length(nxt) == length(de_x)) {
        break
      }
      de_x <- nxt
    }
    label <- paste("rep", rep)

    for (type in c("parents", "backdoor")) {
      z <- tryCatch(
        adjustment_set(cg, X, Y, type = type),
        error = conditionMessage
      )
      if (!grepl("adjustment set", z[1])) {
        expect_true(oracle(z), label = paste(label, type))
      } else if (grepl("No valid adjustment set exists", z)) {
        expect_false(any_valid, label = paste(label, type))
      } else {
        # "parents" was not valid, but another set is.
        expect_true(any_valid, label = paste(label, type))
        expect_false(type == "backdoor", label = paste(label, type))
      }
    }

    # "optimal" answers for Y ∩ De(X) (Henckel et al. 2022, Remark 3.14).
    Yd <- intersect(Y, de_x)
    z <- tryCatch(
      suppressWarnings(adjustment_set(cg, X, Y, type = "optimal")),
      error = conditionMessage
    )
    if (length(Yd) == 0) {
      expect_match(z, "No node in Y is a descendant of X", label = label)
      next
    }
    oracle_d <- .gac_oracle(edges, X, Yd)
    rest_d <- setdiff(nodes, c(X, Yd))
    any_valid_d <- any(vapply(
      unlist(
        lapply(0:length(rest_d), function(k) {
          combn(rest_d, k, simplify = FALSE)
        }),
        recursive = FALSE
      ),
      oracle_d,
      logical(1)
    ))
    if (grepl("No valid adjustment set exists", z[1])) {
      expect_false(any_valid_d, label = paste(label, "optimal"))
    } else {
      expect_true(oracle_d(z), label = paste(label, "optimal"))
    }
  }
})

test_that("adjustment agrees with exact do-calculus in random binary models", {
  subsets_of <- function(s) {
    unlist(
      lapply(0:length(s), function(k) combn(s, k, simplify = FALSE)),
      recursive = FALSE
    )
  }
  key <- function(z) paste(sort(z), collapse = ",")
  set.seed(20261028)

  # ADMGs with bows: every candidate Z.
  nodes <- paste0("V", 1:6)
  for (rep in seq_len(100)) {
    edges <- .random_admg_edges(nodes)
    cg <- caugi(
      from = edges$from,
      edge = edges$edge,
      to = edges$to,
      nodes = nodes,
      class = "ADMG",
      simple = FALSE
    )
    X <- sample(nodes, sample(1:2, 1))
    Y <- sample(setdiff(nodes, X), sample(1:2, 1))
    Zs <- subsets_of(setdiff(nodes, c(X, Y)))
    truth <- .exact_adjustment_gap(edges, nodes, X, Y, Zs) < 1e-10
    got <- vapply(
      Zs,
      function(z) is_valid_adjustment_admg(cg, X = X, Y = Y, Z = z),
      logical(1)
    )
    expect_identical(got, truth, label = paste("ADMG rep", rep))
  }

  # DAGs: adjustment_set() for every type.
  nodes <- paste0("V", 1:6)
  for (rep in seq_len(60)) {
    edges <- .random_admg_edges(nodes, prob = c(0.6, 0.4, 0, 0))
    cg <- caugi(
      from = edges$from,
      edge = edges$edge,
      to = edges$to,
      nodes = nodes,
      class = "DAG"
    )
    X <- sample(nodes, sample(1:2, 1))
    Y <- sample(setdiff(nodes, X), sample(1:2, 1))
    de_x <- X
    repeat {
      nxt <- union(de_x, edges$to[edges$from %in% de_x])
      if (length(nxt) == length(de_x)) {
        break
      }
      de_x <- nxt
    }
    for (type in c("parents", "backdoor", "optimal")) {
      label <- paste("DAG rep", rep, type)
      # "optimal" answers for Y ∩ De(X) (Henckel et al. 2022, Remark 3.14).
      Yt <- if (type == "optimal") intersect(Y, de_x) else Y
      z <- tryCatch(
        suppressWarnings(adjustment_set(cg, X, Y, type = type)),
        error = conditionMessage
      )
      if (length(Yt) == 0) {
        expect_match(z, "No node in Y is a descendant of X", label = label)
        next
      }
      Zs <- subsets_of(setdiff(nodes, c(X, Yt)))
      truth <- .exact_adjustment_gap(edges, nodes, X, Yt, Zs) < 1e-10
      if (length(z) == 1 && grepl("No valid adjustment set exists", z)) {
        expect_false(any(truth), label = label)
      } else if (length(z) == 1 && grepl("adjustment set", z)) {
        # "parents" is not valid here, but another set is.
        expect_true(any(truth), label = label)
      } else {
        expect_true(truth[match(key(z), vapply(Zs, key, ""))], label = label)
      }
    }
  }
})
