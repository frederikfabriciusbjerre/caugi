# Convert to a `caugi`

Convert an object to a `caugi`. The object can be a `graphNEL`,
`matrix`, `tidygraph`, `daggity`, `bn`, or `igraph`.

## Usage

``` r
as_caugi(
  x,
  class = c("DAG", "PDAG", "ADMG", "PAG", "UNKNOWN"),
  simple = TRUE,
  build = TRUE,
  collapse = FALSE,
  collapse_to = "---",
  ...
)
```

## Arguments

- x:

  An object to convert to a `caugi`.

- class:

  "DAG", "PDAG", "ADMG", "PAG", or "UNKNOWN". "PAG" is only supported
  for integer coded matrices. "ADMG" is for Acyclic Directed Mixed
  Graphs (with `-->` and `<->` edges).

- simple:

  logical. If `TRUE` (default) the graph will be simple (no multiple
  edges or self-loops).

- build:

  logical. If `TRUE` (default) build the graph now, otherwise build
  lazily on first query or when using
  [`build()`](https://caugi.org/dev/reference/build.md).

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
have that `G["A", "B"] == 1` and `G["B", "A"] == 0`. For PAGs, the
integer codes are as follows (as used in `pcalg`):

- 0: no edge

- 1: circle (e.g., `A o-o B` or `A o-- B`)

- 2: arrowhead (e.g., `A --> B` or `A o-> B`)

- 3: tail (e.g., `A o-- B` or `A --- B`)

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

# collapse mutual edges
ig2 <- igraph::graph_from_literal(A - +B, B - +A, C - +D)
cg2 <- as_caugi(ig2, class = "PDAG", collapse = TRUE, collapse_to = "---")

# coded integer matrix for PAGs (pcalg style)
nm <- c("A", "B", "C", "D")
M <- matrix(0L, 4, 4, dimnames = list(nm, nm))

# A --> B
M["A", "B"] <- 2L # mark at B end
M["B", "A"] <- 3L # mark at A end

# A --- C
M["A", "C"] <- 3L
M["C", "A"] <- 3L

# B o-> C
M["B", "C"] <- 2L
M["C", "B"] <- 1L

# C o-o D
M["C", "D"] <- 1L
M["D", "C"] <- 1L

cg <- as_caugi(M, class = "PAG")
```
