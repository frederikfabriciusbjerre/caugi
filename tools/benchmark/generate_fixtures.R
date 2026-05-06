#!/usr/bin/env Rscript
# Generate shared graph fixtures + query specs consumed by every language runner.
#
# Output: fixtures/{id}.edges    -- tab-separated `from\tto` edge list (DAG)
#         fixtures/spec.json     -- per-fixture query parameters

suppressPackageStartupMessages({
  library(caugi)
  library(data.table)
  library(jsonlite)
})

set.seed(42L)

FIXTURES_DIR <- "fixtures"
dir.create(FIXTURES_DIR, showWarnings = FALSE, recursive = TRUE)

# (n, p_raw) grid. p_raw is then scaled by 10 * log10(n) / n to keep graphs
# reasonably sparse, matching the convention used in the current vignette.
GRID <- list(
  list(n = 100L, p_raw = 0.5),
  list(n = 500L, p_raw = 0.5),
  list(n = 1000L, p_raw = 0.5),
  list(n = 100L, p_raw = 0.9),
  list(n = 500L, p_raw = 0.9),
  list(n = 1000L, p_raw = 0.9)
)

# How many random (X, Y) pairs to try before giving up on finding a non-empty
# backdoor adjustment set for the d-separation benchmark.
DSEP_TRIES <- 50L

write_edges <- function(cg, path) {
  e <- caugi::edges(cg)
  e <- e[edge == "-->", .(from, to)]
  fwrite(e, file = path, sep = "\t", col.names = FALSE, quote = FALSE)
  nrow(e)
}

find_dsep_triple <- function(cg, nodes) {
  for (i in seq_len(DSEP_TRIES)) {
    pair <- sample(nodes, 2L, replace = FALSE)
    z <- tryCatch(
      caugi::adjustment_set(cg, X = pair[1], Y = pair[2], type = "backdoor"),
      error = function(e) NULL
    )
    if (!is.null(z) && length(z) > 0L) {
      return(list(x = pair[1], y = pair[2], z = as.character(z)))
    }
  }
  NULL
}

fixtures <- list()
for (cell in GRID) {
  n <- cell$n
  p_raw <- cell$p_raw
  p_mod <- 10 * log10(n) / n * p_raw
  # Tag fixtures by raw p so filenames don't carry awkward decimals.
  id <- sprintf("n%d_p%02d", n, as.integer(round(p_raw * 10)))

  message(sprintf("[generate_fixtures] %s: n=%d, p=%.4f", id, n, p_mod))

  cg <- caugi::generate_graph(n = n, p = p_mod, class = "DAG", seed = 42L + n)
  cg <- caugi::build(cg)

  edges_path <- file.path(FIXTURES_DIR, paste0(id, ".edges"))
  n_edges <- write_edges(cg, edges_path)

  nodes <- paste0("V", seq_len(n))
  test_node <- nodes[sample.int(n, 1L)]
  subgraph_nodes <- sort(sample(nodes, max(1L, n %/% 2L)))

  dsep <- find_dsep_triple(cg, nodes)

  fixtures[[length(fixtures) + 1L]] <- list(
    id = id,
    n = n,
    p = p_mod,
    p_raw = p_raw,
    n_edges = n_edges,
    edges_file = paste0(id, ".edges"),
    test_node = test_node,
    subgraph_nodes = subgraph_nodes,
    dsep = dsep
  )
}

spec <- list(
  generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  caugi_version = as.character(utils::packageVersion("caugi")),
  fixtures = fixtures
)

write_json(
  spec,
  path = file.path(FIXTURES_DIR, "spec.json"),
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

message(sprintf(
  "[generate_fixtures] wrote %d fixtures to %s/",
  length(fixtures),
  FIXTURES_DIR
))
