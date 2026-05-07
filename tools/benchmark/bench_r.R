#!/usr/bin/env Rscript
# R benchmark runner: caugi, igraph, bnlearn, dagitty, ggm, pcalg.
#
# Reads fixtures/spec.json + fixtures/*.edges, runs the standard operations
# against each package, writes a long-format CSV to results/r.csv.

suppressPackageStartupMessages({
  library(caugi)
  library(bench)
  library(data.table)
  library(jsonlite)
  library(igraph)
  library(bnlearn)
  library(dagitty)
  library(ggm)
  library(pcalg)
  library(graph)
})

FIXTURES_DIR <- "fixtures"
RESULTS_DIR <- "results"
dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)

spec <- fromJSON(file.path(FIXTURES_DIR, "spec.json"), simplifyVector = FALSE)

load_fixture <- function(fx) {
  edges_path <- file.path(FIXTURES_DIR, fx$edges_file)
  edges <- fread(
    edges_path,
    col.names = c("from", "to"),
    colClasses = "character"
  )
  nodes <- paste0("V", seq_len(fx$n))

  cg <- caugi::add_edges(
    caugi::caugi(class = "DAG", nodes = nodes),
    from = edges$from,
    edge = rep("-->", nrow(edges)),
    to = edges$to
  )
  cg <- caugi::build(cg)

  ig <- igraph::graph_from_data_frame(
    as.data.frame(edges),
    directed = TRUE,
    vertices = data.frame(name = nodes)
  )

  am <- as.matrix(igraph::as_adjacency_matrix(ig))
  storage.mode(am) <- "integer"

  bn <- bnlearn::empty.graph(nodes)
  bnlearn::amat(bn) <- am

  dg_str <- paste0(
    "dag {\n",
    paste(sprintf("%s -> %s", edges$from, edges$to), collapse = "\n"),
    "\n}"
  )
  dg <- dagitty::dagitty(dg_str)

  # pcalg's searchAM expects the PAG-style 0/1/2/3 amat coding (mark at the
  # column-end of edge {row, col}): for a -> b, amat[a,b] = 2 (arrowhead at b)
  # and amat[b,a] = 3 (tail at a).
  amat_pag <- matrix(0L, nrow(am), ncol(am), dimnames = dimnames(am))
  amat_pag[am == 1L] <- 2L
  amat_pag[t(am) == 1L] <- 3L

  # pcalg::dsep operates on a graphNEL.
  gNEL <- igraph::as_graphnel(ig)

  list(
    cg = cg,
    ig = ig,
    bn = bn,
    dg = dg,
    am = am,
    amat_pag = amat_pag,
    gNEL = gNEL,
    nodes = nodes
  )
}

# bench::mark returns a tibble; we convert each row into a long-format record.
mark_to_rows <- function(bm, operation, fx) {
  pkg <- as.character(bm$expression)
  data.table(
    language = rep("R", length(pkg)),
    package = pkg,
    operation = rep(operation, length(pkg)),
    fixture_id = rep(fx$id, length(pkg)),
    n = rep(fx$n, length(pkg)),
    p = rep(fx$p, length(pkg)),
    n_edges = rep(fx$n_edges, length(pkg)),
    median_ns = as.numeric(bm$median) * 1e9,
    min_ns = as.numeric(bm$min) * 1e9,
    total_time_ns = as.numeric(bm$total_time) * 1e9,
    n_iter = as.integer(bm$n_itr),
    mem_alloc_bytes = as.numeric(bm$mem_alloc)
  )
}

results <- list()

for (fx in spec$fixtures) {
  message(sprintf("[bench_r] %s (n=%d, edges=%d)", fx$id, fx$n, fx$n_edges))
  graphs <- load_fixture(fx)
  cg <- graphs$cg
  ig <- graphs$ig
  bn <- graphs$bn
  dg <- graphs$dg
  am <- graphs$am
  amat_pag <- graphs$amat_pag
  gNEL <- graphs$gNEL
  v <- fx$test_node
  v_idx <- match(v, graphs$nodes)

  # ---- parents
  bm <- bench::mark(
    caugi = caugi::parents(cg, v),
    igraph = igraph::neighbors(ig, v, mode = "in"),
    bnlearn = bnlearn::parents(bn, v),
    dagitty = dagitty::parents(dg, v),
    ggm = ggm::pa(v, am),
    pcalg = pcalg::searchAM(amat_pag, v_idx, type = "pa"),
    check = FALSE,
    min_iterations = 5,
    time_unit = "s"
  )
  results[[length(results) + 1L]] <- mark_to_rows(bm, "parents", fx)

  # ---- children
  bm <- bench::mark(
    caugi = caugi::children(cg, v),
    igraph = igraph::neighbors(ig, v, mode = "out"),
    bnlearn = bnlearn::children(bn, v),
    dagitty = dagitty::children(dg, v),
    ggm = ggm::ch(v, am),
    pcalg = pcalg::searchAM(amat_pag, v_idx, type = "ch"),
    check = FALSE,
    min_iterations = 5,
    time_unit = "s"
  )
  results[[length(results) + 1L]] <- mark_to_rows(bm, "children", fx)

  # ---- ancestors (no ggm equivalent)
  bm <- bench::mark(
    caugi = caugi::ancestors(cg, v),
    igraph = igraph::subcomponent(ig, v, mode = "in"),
    bnlearn = bnlearn::ancestors(bn, v),
    dagitty = dagitty::ancestors(dg, v),
    pcalg = pcalg::searchAM(amat_pag, v_idx, type = "an"),
    check = FALSE,
    min_iterations = 5,
    time_unit = "s"
  )
  results[[length(results) + 1L]] <- mark_to_rows(bm, "ancestors", fx)

  # ---- descendants
  bm <- bench::mark(
    caugi = caugi::descendants(cg, v),
    igraph = igraph::subcomponent(ig, v, mode = "out"),
    bnlearn = bnlearn::descendants(bn, v),
    dagitty = dagitty::descendants(dg, v),
    pcalg = pcalg::searchAM(amat_pag, v_idx, type = "de"),
    check = FALSE,
    min_iterations = 5,
    time_unit = "s"
  )
  results[[length(results) + 1L]] <- mark_to_rows(bm, "descendants", fx)

  # ---- d-separation (caugi / bnlearn / dagitty / pcalg)
  if (!is.null(fx$dsep)) {
    x <- fx$dsep$x
    y <- fx$dsep$y
    z <- unlist(fx$dsep$z)
    bm <- bench::mark(
      caugi = caugi::d_separated(cg, x, y, z),
      bnlearn = bnlearn::dsep(bn, x, y, z),
      dagitty = dagitty::dseparated(dg, x, y, z),
      pcalg = pcalg::dsep(x, y, z, gNEL),
      check = FALSE,
      min_iterations = 5,
      time_unit = "s"
    )
    results[[length(results) + 1L]] <- mark_to_rows(bm, "d_separated", fx)
  }

  # ---- markov blanket (caugi / bnlearn / dagitty)
  bm <- bench::mark(
    caugi = caugi::markov_blanket(cg, v),
    bnlearn = bnlearn::mb(bn, v),
    dagitty = dagitty::markovBlanket(dg, v),
    check = FALSE,
    min_iterations = 5,
    time_unit = "s"
  )
  results[[length(results) + 1L]] <- mark_to_rows(bm, "markov_blanket", fx)

  # ---- subgraph (caugi forces full rebuild via build()) — caugi / igraph / bnlearn
  sub <- unlist(fx$subgraph_nodes)
  bm <- bench::mark(
    caugi = {
      sg <- caugi::subgraph(cg, sub)
      caugi::build(sg)
    },
    igraph = igraph::subgraph(ig, sub),
    bnlearn = bnlearn::subgraph(bn, sub),
    check = FALSE,
    min_iterations = 5,
    time_unit = "s"
  )
  results[[length(results) + 1L]] <- mark_to_rows(bm, "subgraph", fx)
}

out <- rbindlist(results)
fwrite(out, file = file.path(RESULTS_DIR, "r.csv"))
message(sprintf("[bench_r] wrote %d rows to %s/r.csv", nrow(out), RESULTS_DIR))
