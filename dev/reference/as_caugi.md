# Convert to a `caugi`

Convert an object to a `caugi`. The object can be a `graphNEL`,
`matrix`, `tidygraph`, `dagitty`, `bn`, `igraph`, or a `data.frame` edge
list with columns `from`, `edge` and `to`, as written by
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) (rows
with an `NA` edge are isolated nodes).

## Usage

``` r
as_caugi(
  x,
  class = c("DAG", "UG", "PDAG", "MPDAG", "CPDAG", "ADMG", "AG", "PAG", "UNKNOWN"),
  simple = NULL,
  collapse = FALSE,
  collapse_to = "---",
  ...
)
```

## Arguments

- x:

  An object to convert to a `caugi`.

- class:

  Character; one of `"DAG"`, `"UG"`, `"PDAG"`, `"MPDAG"`, `"CPDAG"`,
  `"ADMG"`, `"AG"`, or `"UNKNOWN"`. `"PAG"` is supported for integer
  coded matrices, data.frames and `dagitty` objects, and is validated as
  in [`caugi()`](https://caugi.org/dev/reference/caugi.md). For a
  data.frame, it defaults to the data.frame's `"graph_class"` attribute,
  which [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  sets, if present.

- simple:

  Deprecated; see [`caugi()`](https://caugi.org/dev/reference/caugi.md).
  If omitted (recommended), it is derived from `class`.

- collapse:

  logical. If `TRUE` collapse mutual directed edges to undirected edges.
  Default is `FALSE`.

- collapse_to:

  Character string to use as the edge glyph when collapsing. Should be a
  registered symmetrical edge glyph. Default is `"---"`.

- ...:

  Additional arguments passed to specific methods.

## Value

A `caugi` object.

## Details

For matrices, `as_caugi` assumes that the rows are the `from` nodes and
the columns are the `to` nodes. Thus, for a graph, G: A –\> B, we would
have that `G["A", "B"] == 1` and `G["B", "A"] == 0`. A matrix that
contains the codes `2` or `3`, or any matrix passed with
`class = "PAG"`, is instead read in `pcalg`'s `amat.pag` mark coding,
where `G[i, j]` is the mark at node `j` on the edge between `i` and `j`:

- 0: no edge

- 1: circle (e.g., `A o-o B` or `A --o B`)

- 2: arrowhead (e.g., `A --> B` or `A o-> B`)

- 3: tail (e.g., `A --o B` or `A --- B`)

This holds for every `class`, so a MAG coded this way can be read with
`class = "AG"`, and a graph with circle marks with `class = "UNKNOWN"`.

## See also

Other conversions:
[`as_adjacency()`](https://caugi.org/dev/reference/as_adjacency.md),
[`as_bnlearn()`](https://caugi.org/dev/reference/as_bnlearn.md),
[`as_dagitty()`](https://caugi.org/dev/reference/as_dagitty.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md)

## Examples

``` r
# igraph
ig <- igraph::graph_from_literal(A - +B, B - +C)
cg_ig <- as_caugi(ig, class = "DAG")

# graphNEL
gn <- graph::graphNEL(nodes = c("A", "B", "C"), edgemode = "directed")
gn <- graph::addEdge("A", "B", gn)
gn <- graph::addEdge("B", "C", gn)
cg_gn <- as_caugi(gn, class = "DAG")

# adjacency matrix
m <- matrix(0L, 3, 3, dimnames = list(LETTERS[1:3], LETTERS[1:3]))
m["A", "B"] <- 1L
m["B", "C"] <- 1L
cg_adj <- as_caugi(m, class = "DAG")

# bnlearn
bn <- bnlearn::model2network("[A][B|A][C|B]")
cg_bn <- as_caugi(bn, class = "DAG")

# dagitty
dg <- dagitty::dagitty("dag {
 A -> B
 B -> C
 }")
cg_dg <- as_caugi(dg, class = "DAG")

cg <- caugi(A %-->% B %-->% C, class = "DAG")

# check that all nodes are equal in all graph objects
for (cg_converted in list(cg_ig, cg_gn, cg_adj, cg_bn, cg_dg)) {
  stopifnot(identical(nodes(cg), nodes(cg_converted)))
  stopifnot(identical(edges(cg), edges(cg_converted)))
}

# data.frame edge list
cg_df <- as_caugi(as.data.frame(cg), class = "DAG")

# collapse mutual edges
ig2 <- igraph::graph_from_literal(A - +B, B - +A, C - +D)
cg2 <- as_caugi(ig2, class = "PDAG", collapse = TRUE, collapse_to = "---")

# coded integer matrix for PAGs (pcalg style). `class = "PAG"` is fully
# validated, so the marks must be the invariant marks of a Markov
# equivalence class; these are.
nm <- c("A", "B", "C", "D")
M <- matrix(0L, 4, 4, dimnames = list(nm, nm))

# A --> B
M["A", "B"] <- 2L # arrowhead at B
M["B", "A"] <- 3L # tail at A

# A o-> C
M["A", "C"] <- 2L # arrowhead at C
M["C", "A"] <- 1L # circle at A

# C --> B
M["C", "B"] <- 2L # arrowhead at B
M["B", "C"] <- 3L # tail at C

# D o-> C
M["D", "C"] <- 2L # arrowhead at C
M["C", "D"] <- 1L # circle at D

cg <- as_caugi(M, class = "PAG")
```
