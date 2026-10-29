# Reference check for meek_closure().
#
# Inputs are the pattern of a random DAG (skeleton, v-structure edges directed)
# plus background knowledge: a random subset of the DAG's other edges, directed
# as in the DAG. The DAG is a consistent extension, so every input is
# extendable, and Meek's rules R1-R4 are sound and complete for it (Meek 1995).
#
# Two independent references:
# * pcalg::addBgKnowledge(), which applies R1-R4 (Perkovic et al. 2017).
# * A brute-force oracle from the definition: an edge is oriented a -> b iff
#   every consistent extension (acyclic, keeps the directed edges, same
#   v-structures) has a -> b.
#
# Edges are encoded as "a->b" (directed) and "a|b" with a < b (undirected).

# paste() with sep (not paste0 with a literal) keeps zero-length input empty.
.meek_key <- function(a, b) paste(a, b, sep = "->")
.meek_ukey <- function(a, b) paste(pmin(a, b), pmax(a, b), sep = "|")

# Random pattern + background knowledge, with at most `max_und` undirected edges.
.meek_random_input <- function(max_und) {
  repeat {
    n <- sample(5:8, 1)
    nodes <- LETTERS[seq_len(n)]
    ord <- sample(nodes)
    pairs <- t(utils::combn(n, 2))
    keep <- stats::runif(nrow(pairs)) < stats::runif(1, 0.3, 0.7)
    dag <- cbind(ord[pairs[keep, 1]], ord[pairs[keep, 2]])
    adj <- matrix(FALSE, n, n, dimnames = list(nodes, nodes))
    adj[dag] <- TRUE
    adj[dag[, 2:1, drop = FALSE]] <- TRUE
    in_vstruct <- vapply(
      seq_len(nrow(dag)),
      function(i) {
        others <- setdiff(dag[dag[, 2] == dag[i, 2], 1], dag[i, 1])
        any(!adj[dag[i, 1], others])
      },
      logical(1)
    )
    bk <- stats::runif(nrow(dag)) < stats::runif(1, 0, 0.5)
    is_dir <- in_vstruct | bk
    und <- dag[!is_dir, , drop = FALSE]
    if (nrow(und) > 0 && nrow(und) <= max_und) {
      return(list(
        nodes = nodes,
        adj = adj,
        dir = dag[is_dir, , drop = FALSE],
        und = und
      ))
    }
  }
}

.meek_vstructs <- function(from, to, adj) {
  out <- character(0)
  for (c in unique(to)) {
    pa <- sort(from[to == c])
    for (i in seq_along(pa)) {
      for (j in seq_along(pa)) {
        if (i < j && !adj[pa[i], pa[j]]) out <- c(out, paste(pa[i], c, pa[j]))
      }
    }
  }
  sort(out)
}

.meek_acyclic <- function(nodes, from, to) {
  indeg <- table(factor(to, levels = nodes))
  queue <- nodes[indeg == 0]
  seen <- 0L
  while (length(queue)) {
    v <- queue[1]
    queue <- queue[-1]
    seen <- seen + 1L
    for (t in to[from == v]) {
      indeg[t] <- indeg[t] - 1L
      if (indeg[t] == 0L) queue <- c(queue, t)
    }
  }
  seen == length(nodes)
}

.meek_oracle <- function(x) {
  vs <- .meek_vstructs(x$dir[, 1], x$dir[, 2], x$adj)
  k <- nrow(x$und)
  flips <- list()
  for (code in 0:(2^k - 1)) {
    flip <- as.logical(intToBits(code))[seq_len(k)]
    from <- c(x$dir[, 1], ifelse(flip, x$und[, 2], x$und[, 1]))
    to <- c(x$dir[, 2], ifelse(flip, x$und[, 1], x$und[, 2]))
    if (
      .meek_acyclic(x$nodes, from, to) &&
        identical(.meek_vstructs(from, to, x$adj), vs)
    ) {
      flips[[length(flips) + 1L]] <- flip
    }
  }
  m <- do.call(rbind, flips)
  und <- vapply(
    seq_len(k),
    function(e) {
      if (!any(m[, e])) {
        .meek_key(x$und[e, 1], x$und[e, 2])
      } else if (all(m[, e])) {
        .meek_key(x$und[e, 2], x$und[e, 1])
      } else {
        .meek_ukey(x$und[e, 1], x$und[e, 2])
      }
    },
    character(1)
  )
  sort(c(.meek_key(x$dir[, 1], x$dir[, 2]), und))
}

.meek_caugi <- function(x) {
  cg <- caugi(
    from = c(x$dir[, 1], x$und[, 1]),
    edge = rep(c("-->", "---"), c(nrow(x$dir), nrow(x$und))),
    to = c(x$dir[, 2], x$und[, 2]),
    nodes = x$nodes,
    class = "PDAG"
  )
  e <- edges(meek_closure(cg))
  sort(ifelse(
    e$edge == "-->",
    .meek_key(e$from, e$to),
    .meek_ukey(e$from, e$to)
  ))
}

.meek_pcalg <- function(x) {
  # pcalg amat.cpdag convention: m[to, from] = 1 for from -> to.
  m <- matrix(
    0,
    length(x$nodes),
    length(x$nodes),
    dimnames = list(x$nodes, x$nodes)
  )
  m[x$dir[, 2:1, drop = FALSE]] <- 1
  m[x$und] <- 1
  m[x$und[, 2:1, drop = FALSE]] <- 1
  r <- pcalg::addBgKnowledge(m, checkInput = FALSE)
  out <- character(0)
  for (a in x$nodes) {
    for (b in x$nodes) {
      if (a < b && (r[a, b] == 1 || r[b, a] == 1)) {
        out <- c(
          out,
          if (r[a, b] == 0) {
            .meek_key(a, b)
          } else if (r[b, a] == 0) {
            .meek_key(b, a)
          } else {
            .meek_ukey(a, b)
          }
        )
      }
    }
  }
  sort(out)
}

test_that("meek_closure matches pcalg::addBgKnowledge on random inputs", {
  skip_on_cran()
  skip_if_not_installed("pcalg")
  set.seed(379)
  for (i in 1:200) {
    x <- .meek_random_input(max_und = 20)
    expect_identical(.meek_caugi(x), .meek_pcalg(x), info = paste("case", i))
  }
})

test_that("meek_closure matches the brute-force extension oracle", {
  skip_on_cran()
  set.seed(1995)
  for (i in 1:100) {
    x <- .meek_random_input(max_und = 9)
    expect_identical(.meek_caugi(x), .meek_oracle(x), info = paste("case", i))
  }
})
