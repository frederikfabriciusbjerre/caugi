## Ground truth for PAG validity on small node sets.
##
## Builds the COMPLETE set of valid PAGs on `n` nodes straight from the
## definition, using `ggm::msep` as the only separation primitive. Nothing in
## here uses caugi, FCI, the orientation rules R0-R10, or Zhang's construction,
## so the output is independent of every component `is_pag()` is built from.
##
## Recipe:
##   1. enumerate every mixed graph on n nodes over {none, -->, <--, <->, ---}
##   2. keep the ancestral ones (Richardson & Spirtes conditions i-iii)
##   3. keep the maximal ones (non-adjacent <=> some separating set exists)
##   4. group into Markov equivalence classes by full pairwise m-separation
##   5. PAG(class): a mark is definite iff it is constant across the class,
##      otherwise it is a circle. Adjacency is invariant, so 0 is preserved.
##
## Self-checks (both MUST hold, or the oracle is broken and must not be used):
##   * no equivalence class contains two different skeletons
##   * classes correspond 1:1 to distinct PAGs (a PAG is a complete invariant)
##
## WARNING: do not swap `ggm::msep` for `pcalg::dsepAM`. dsepAM ignores
## undirected edges -- on a graph that is only `A --- B` it reports A and B as
## m-separated by the empty set -- which silently merges equivalence classes
## whenever selection bias is present. See todo.md.
##
## Run offline. Output is committed as a static fixture; runtime does not
## matter (n = 4 takes ~70s).
##
## Usage: Rscript tools/pag-ground-truth/generate.R [n] [outfile] [max_edges] [backend]

suppressMessages(library(ggm))

args <- commandArgs(trailingOnly = TRUE)
n <- if (length(args) >= 1) as.integer(args[1]) else 4L
out <- if (length(args) >= 2) {
  args[2]
} else {
  sprintf("tests/testthat/fixtures/pag-ground-truth-n%d.rds", n)
}
## Cap on skeleton size, for tractability at larger n. Sound because Markov
## equivalence preserves the skeleton; see the enumeration below.
max_edges <- if (length(args) >= 3) {
  as.integer(args[3])
} else {
  .Machine$integer.max
}

## Which m-separation implementation to use as the primitive.
##
## `"ggm"` (default) is fully independent of caugi and is how the committed
## n = 4 fixture was produced. `"caugi"` calls caugi's own `m_separated()`,
## which is ~20x faster and is what makes n = 5 tractable at all -- the ggm
## run did not finish in five hours.
##
## Using caugi here is a chain of trust, not circular reasoning: its ancestral
## m-separation is differential-tested against `ggm::msep` over all 3,045
## four-node MAGs x 24 queries, 73,080 comparisons with zero mismatches
## (`tests/testthat/test-ag-msep-oracle.R`). To keep that honest, whenever this
## backend is used at n = 4 the generator re-derives the fixture and asserts the
## PAG set is identical to the committed, ggm-derived one. If the two ever
## diverge this fails loudly rather than silently producing a wrong fixture.
backend <- if (length(args) >= 4) args[4] else "ggm"
stopifnot("backend must be 'ggm' or 'caugi'" = backend %in% c("ggm", "caugi"))
if (identical(backend, "caugi")) {
  suppressMessages(requireNamespace("caugi", quietly = TRUE)) ||
    stop("the 'caugi' backend needs the package loaded (devtools::load_all())")
}

V <- seq_len(n)
NM <- paste0("N", V)
pairs <- combn(n, 2, simplify = FALSE)

## amat.pag convention: amat[i, j] is the mark AT j on the edge {i, j}.
## 0 = no edge, 1 = circle, 2 = arrowhead, 3 = tail.
states <- list(
  none = c(0, 0),
  fwd = c(2, 3),
  bwd = c(3, 2),
  bi = c(2, 2),
  und = c(3, 3)
)

anc_matrix <- function(A) {
  D <- (A == 2 & t(A) == 3) # D[i, j] iff i --> j
  R <- D
  repeat {
    R2 <- (R | ((R %*% D) > 0))
    if (identical(R2, R)) {
      break
    }
    R <- R2
  }
  R
}

is_ancestral <- function(A) {
  R <- anc_matrix(A)
  if (any(diag(R))) {
    return(FALSE)
  } # (i) no directed cycle
  for (p in pairs) {
    i <- p[1]
    j <- p[2]
    # (ii) no almost directed cycle
    if (A[i, j] == 2 && A[j, i] == 2 && (R[i, j] || R[j, i])) {
      return(FALSE)
    }
    # (iii) an undirected endpoint carries no arrowhead
    if (
      A[i, j] == 3 && A[j, i] == 3 && (any(A[, i] == 2) || any(A[, j] == 2))
    ) {
      return(FALSE)
    }
  }
  TRUE
}

subsets_of <- function(s) {
  if (!length(s)) {
    return(list(integer(0)))
  }
  do.call(c, lapply(0:length(s), function(k) combn(s, k, simplify = FALSE)))
}

to_triples <- function(A) {
  tr <- character(0)
  for (p in pairs) {
    i <- p[1]
    j <- p[2]
    if (A[i, j] == 2 && A[j, i] == 3) {
      tr <- c(tr, "a", NM[i], NM[j])
    } else if (A[i, j] == 3 && A[j, i] == 2) {
      tr <- c(tr, "a", NM[j], NM[i])
    } else if (A[i, j] == 2 && A[j, i] == 2) {
      tr <- c(tr, "b", NM[i], NM[j])
    } else if (A[i, j] == 3 && A[j, i] == 3) {
      tr <- c(tr, "l", NM[i], NM[j])
    }
  }
  tr
}

## An isolated node appears in no triple; it is separated from everything.
msep_ok <- function(tr, present, i, j, S) {
  if (!(NM[i] %in% present) || !(NM[j] %in% present)) {
    return(TRUE)
  }
  ggm::msep(tr, NM[i], NM[j], intersect(NM[S], present))
}

## The caugi backend works on a prebuilt graph rather than the triple list, so
## it takes the graph in place of `tr`/`present`.
caugi_graph_of <- function(A) {
  from <- character(0)
  to <- character(0)
  edge <- character(0)
  for (p in pairs) {
    i <- p[1]
    j <- p[2]
    if (A[i, j] == 2 && A[j, i] == 3) {
      from <- c(from, NM[i])
      to <- c(to, NM[j])
      edge <- c(edge, "-->")
    } else if (A[i, j] == 3 && A[j, i] == 2) {
      from <- c(from, NM[j])
      to <- c(to, NM[i])
      edge <- c(edge, "-->")
    } else if (A[i, j] == 2 && A[j, i] == 2) {
      from <- c(from, NM[i])
      to <- c(to, NM[j])
      edge <- c(edge, "<->")
    } else if (A[i, j] == 3 && A[j, i] == 3) {
      from <- c(from, NM[i])
      to <- c(to, NM[j])
      edge <- c(edge, "---")
    }
  }
  caugi::caugi(
    from = from,
    edge = edge,
    to = to,
    nodes = NM,
    class = "AG"
  )
}

msep_ok_caugi <- function(cg, i, j, S) {
  caugi::m_separated(
    cg,
    X = NM[i],
    Y = NM[j],
    Z = if (length(S)) NM[S] else NULL
  )
}

separable <- function(query, p) {
  any(vapply(
    subsets_of(setdiff(V, p)),
    function(S) query(p[1], p[2], S),
    logical(1)
  ))
}

## 1-4. enumerate, keep the MAGs, record signatures -------------------------
##
## Enumerated skeleton by skeleton rather than as one big grid: at n = 5 the
## full grid is 5^10 rows, which will not fit in memory. Each present edge
## takes one of four orientations, so a skeleton with k edges contributes 4^k
## assignments and the total is still 5^|pairs|.
##
## `max_edges` caps the skeleton size. That is sound because Markov equivalent
## MAGs share a skeleton, so every surviving equivalence class stays complete:
## a class is either fully enumerated or fully excluded, never truncated. A
## truncated class would silently yield a wrong PAG.
##
## Ancestral, maximal and signature run in one pass, so nothing larger than the
## surviving MAG list is held in memory.

edge_states <- c("fwd", "bwd", "bi", "und") # a present edge is one of four
n_pairs <- length(pairs)
cap <- min(max_edges, n_pairs)

mags <- list()
sigs <- character(0)
sig_rows <- list()
n_candidates <- 0L
n_ancestral <- 0L

for (k in 0:cap) {
  skels <- if (k == 0L) {
    list(integer(0))
  } else {
    combn(n_pairs, k, simplify = FALSE)
  }
  for (sk in skels) {
    for (code in seq_len(4^k) - 1L) {
      A <- matrix(0L, n, n)
      rest <- code
      for (e in seq_along(sk)) {
        st <- states[[edge_states[(rest %% 4L) + 1L]]]
        rest <- rest %/% 4L
        pr <- pairs[[sk[e]]]
        A[pr[1], pr[2]] <- st[1]
        A[pr[2], pr[1]] <- st[2]
      }
      n_candidates <- n_candidates + 1L
      if (!is_ancestral(A)) {
        next
      }
      n_ancestral <- n_ancestral + 1L

      query <- if (identical(backend, "caugi")) {
        cg <- caugi_graph_of(A)
        function(i, j, S) msep_ok_caugi(cg, i, j, S)
      } else {
        tr <- to_triples(A)
        present <- intersect(NM, tr)
        function(i, j, S) msep_ok(tr, present, i, j, S)
      }

      ok <- TRUE
      for (pr in pairs) {
        adjacent <- A[pr[1], pr[2]] != 0
        # maximal: non-adjacent pairs are separable; adjacent pairs never are
        if (separable(query, pr) == adjacent) {
          ok <- FALSE
          break
        }
      }
      if (!ok) {
        next
      }

      sigv <- unlist(lapply(pairs, function(pr) {
        vapply(
          subsets_of(setdiff(V, pr)),
          function(S) query(pr[1], pr[2], S),
          logical(1)
        )
      }))
      mags[[length(mags) + 1L]] <- A
      sigs <- c(sigs, paste(as.integer(sigv), collapse = "")) # fixed width
      sig_rows[[length(sig_rows) + 1L]] <- sigv
    }
  }
}
message("candidates: ", n_candidates)
message("ancestral graphs: ", n_ancestral)
message("MAGs: ", length(mags))

## explicit (i, j, S) query order backing every signature bit, so consumers do
## not have to re-derive it
queries <- do.call(
  c,
  lapply(pairs, function(p) {
    lapply(subsets_of(setdiff(V, p)), function(S) {
      list(i = p[1], j = p[2], S = S)
    })
  })
)

classes <- split(seq_along(mags), sigs)
message("Markov equivalence classes: ", length(classes))

## 5. PAG per class ----------------------------------------------------------
pag_of_class <- function(cl) {
  P <- matrix(0L, n, n)
  for (i in V) {
    for (j in V) {
      if (i == j) {
        next
      }
      vals <- unique(vapply(cl, function(m) mags[[m]][i, j], numeric(1)))
      P[i, j] <- if (length(vals) == 1L) vals else 1L
    }
  }
  P
}
pags <- lapply(classes, pag_of_class)
keys <- unname(vapply(pags, function(P) paste(P, collapse = ","), character(1)))

## self-checks ---------------------------------------------------------------
skel <- function(A) paste((A != 0)[upper.tri(A)], collapse = "")
mixed <- sum(vapply(
  classes,
  function(cl) {
    length(unique(vapply(cl, function(m) skel(mags[[m]]), character(1)))) > 1L
  },
  logical(1)
))
stopifnot(
  "an equivalence class contains two skeletons" = mixed == 0L,
  "classes are not 1:1 with PAGs" = length(unique(keys)) == length(classes)
)
## Chain-of-trust guard: with the caugi backend at n = 4, the result must be
## identical to the committed ggm-derived fixture.
if (identical(backend, "caugi") && n == 4L) {
  ref_path <- "tests/testthat/fixtures/pag-ground-truth-n4.rds"
  if (file.exists(ref_path)) {
    ref <- readRDS(ref_path)
    stopifnot(
      "caugi backend disagrees with the ggm-derived n = 4 fixture" = identical(
        sort(unique(keys)),
        sort(unique(ref$keys))
      )
    )
    message("caugi backend reproduces the ggm-derived n = 4 fixture exactly")
  }
}

message("valid PAGs on ", n, " nodes: ", length(keys), "  (self-checks passed)")

dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
saveRDS(
  list(
    n = n,
    max_edges = cap,
    pags = pags,
    keys = keys,
    mags = mags,
    classes = classes,
    msep = do.call(rbind, sig_rows), # n_mags x n_queries logical, from ggm::msep
    queries = queries,
    n_mags = length(mags),
    n_classes = length(classes)
  ),
  out
)
message("wrote ", out)
