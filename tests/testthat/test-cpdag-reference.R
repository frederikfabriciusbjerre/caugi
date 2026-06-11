# Reference check for caugi's DAG -> CPDAG construction.
#
# Each case hard-codes a DAG together with its expected CPDAG (essential graph).
# The expected values were computed with pcalg::dag2cpdag() and independently
# confirmed to agree with bnlearn::cpdag(); they are recorded here so the test
# itself depends only on base R and caugi. The CPDAG is encoded canonically as
# two sorted character vectors: directed edges "a|b" (a -> b) and undirected
# edges "a|b" with a < b (a -- b).

# caugi DAG -> CPDAG via the same Rust transform `generate_graph()` uses,
# returned in the canonical representation described above.
.caugi_cpdag <- function(node_names, dag_edges) {
  if (nrow(dag_edges) == 0L) {
    cg <- caugi(nodes = node_names, class = "DAG")
  } else {
    edf <- data.frame(
      from = dag_edges[, 1],
      edge = "-->",
      to = dag_edges[, 2],
      stringsAsFactors = FALSE
    )
    cg <- caugi(nodes = node_names, edges_df = edf, class = "DAG")
  }
  cp <- .session_to_caugi(
    rs_to_cpdag(cg@session),
    node_names = node_names
  )
  e <- edges(cp)
  dir <- und <- character(0)
  if (nrow(e) > 0L) {
    for (k in seq_len(nrow(e))) {
      if (e$edge[k] == "-->") {
        dir <- c(dir, paste(e$from[k], e$to[k], sep = "|"))
      } else {
        und <- c(und, paste(sort(c(e$from[k], e$to[k])), collapse = "|"))
      }
    }
  }
  list(class = cp@graph_class, dir = sort(dir), und = sort(und))
}

# label, nodes, DAG edges (from, to), and the expected canonical CPDAG.
cpdag_cases <- list(
  list(
    label = "v-structure: A->C<-B (collider stays directed)",
    nodes = c("A", "B", "C"),
    dag = rbind(c("A", "C"), c("B", "C")),
    dir = c("A|C", "B|C"),
    und = character(0)
  ),
  list(
    label = "chain: A->B->C (no v-structure, all undirected)",
    nodes = c("A", "B", "C"),
    dag = rbind(c("A", "B"), c("B", "C")),
    dir = character(0),
    und = c("A|B", "B|C")
  ),
  list(
    label = "fork: A->B, A->C (all undirected)",
    nodes = c("A", "B", "C"),
    dag = rbind(c("A", "B"), c("A", "C")),
    dir = character(0),
    und = c("A|B", "A|C")
  ),
  list(
    label = "diamond: A->B->D, A->C->D",
    nodes = c("A", "B", "C", "D"),
    dag = rbind(c("A", "B"), c("B", "D"), c("A", "C"), c("C", "D")),
    dir = c("B|D", "C|D"),
    und = c("A|B", "A|C")
  ),
  list(
    label = "collider then chain: A->C<-B, C->D",
    nodes = c("A", "B", "C", "D"),
    dag = rbind(c("A", "C"), c("B", "C"), c("C", "D")),
    dir = c("A|C", "B|C", "C|D"),
    und = character(0)
  ),
  list(
    label = "triangle with shortcut: A->B->C, A->C (all undirected)",
    nodes = c("A", "B", "C"),
    dag = rbind(c("A", "B"), c("B", "C"), c("A", "C")),
    dir = character(0),
    und = c("A|B", "A|C", "B|C")
  ),
  list(
    label = "three parents collide: A->C<-B, D->C",
    nodes = c("A", "B", "C", "D"),
    dag = rbind(c("A", "C"), c("B", "C"), c("D", "C")),
    dir = c("A|C", "B|C", "D|C"),
    und = character(0)
  ),
  list(
    label = "Meek-propagated: A->B->C, D->C",
    nodes = c("A", "B", "C", "D"),
    dag = rbind(c("A", "B"), c("B", "C"), c("D", "C")),
    dir = c("B|C", "D|C"),
    und = c("A|B")
  ),
  list(
    label = "star out: A->B, A->C, A->D (all undirected)",
    nodes = c("A", "B", "C", "D"),
    dag = rbind(c("A", "B"), c("A", "C"), c("A", "D")),
    dir = character(0),
    und = c("A|B", "A|C", "A|D")
  ),
  list(
    label = "complete DAG on 4 nodes (fully undirected CPDAG)",
    nodes = c("A", "B", "C", "D"),
    dag = rbind(
      c("A", "B"),
      c("A", "C"),
      c("A", "D"),
      c("B", "C"),
      c("B", "D"),
      c("C", "D")
    ),
    dir = character(0),
    und = c("A|B", "A|C", "A|D", "B|C", "B|D", "C|D")
  )
)

test_that("caugi DAG -> CPDAG matches recorded reference essential graphs", {
  for (case in cpdag_cases) {
    out <- .caugi_cpdag(case$nodes, case$dag)
    expect_identical(out$class, "CPDAG", info = case$label)
    expect_identical(out$dir, case$dir, info = case$label)
    expect_identical(out$und, case$und, info = case$label)
  }
})
