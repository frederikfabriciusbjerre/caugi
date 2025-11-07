# Is the `caugi` graph a DAG?

Checks if the given `caugi` graph is a Directed Acyclic Graph (DAG).

## Usage

``` r
is_dag(cg, force_check = FALSE)
```

## Arguments

- cg:

  A `caugi` object.

- force_check:

  Logical; if `TRUE`, the function will test if the graph is a DAG, if
  `FALSE` (default), it will look at the graph class and match it, if
  possible.

## Value

A logical value indicating whether the graph is a DAG.

## See also

Other queries:
[`ancestors()`](https://frederikfabriciusbjerre.github.io/caugi/reference/ancestors.md),
[`children()`](https://frederikfabriciusbjerre.github.io/caugi/reference/children.md),
[`descendants()`](https://frederikfabriciusbjerre.github.io/caugi/reference/descendants.md),
[`edge_types()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edge_types.md),
[`edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edges.md),
[`exogenous()`](https://frederikfabriciusbjerre.github.io/caugi/reference/exogenous.md),
[`is_acyclic()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_acyclic.md),
[`is_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_caugi.md),
[`is_cpdag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_cpdag.md),
[`is_empty_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_empty_caugi.md),
[`is_pdag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_pdag.md),
[`markov_blanket()`](https://frederikfabriciusbjerre.github.io/caugi/reference/markov_blanket.md),
[`neighbors()`](https://frederikfabriciusbjerre.github.io/caugi/reference/neighbors.md),
[`nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/nodes.md),
[`parents()`](https://frederikfabriciusbjerre.github.io/caugi/reference/parents.md),
[`same_nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/same_nodes.md),
[`subgraph()`](https://frederikfabriciusbjerre.github.io/caugi/reference/subgraph.md)

## Examples

``` r
cg_dag_class <- caugi(
  A %-->% B,
  class = "DAG"
)
is_dag(cg_dag_class) # TRUE
#> [1] TRUE
cg_dag_but_pdag_class <- caugi(
  A %-->% B,
  class = "PDAG"
)
is_dag(cg_dag_but_pdag_class) # TRUE
#> [1] TRUE
cg_cyclic <- caugi(
  A %-->% B,
  B %-->% C,
  C %-->% A,
  class = "UNKNOWN",
  simple = FALSE
)
is_dag(cg_cyclic) # FALSE
#> [1] FALSE

cg_undirected <- caugi(
  A %---% B,
  class = "UNKNOWN"
)
is_dag(cg_undirected) # FALSE
#> [1] FALSE
```
