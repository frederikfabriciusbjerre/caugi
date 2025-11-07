# Is the `caugi` acyclic?

Checks if the given `caugi` graph is acyclic.

## Usage

``` r
is_acyclic(cg, force_check = FALSE)
```

## Arguments

- cg:

  A `caugi` object.

- force_check:

  Logical; if `TRUE`, the function will test if the graph is acyclic, if
  `FALSE` (default), it will look at the graph class and match it, if
  possible.

## Value

A logical value indicating whether the graph is acyclic.

## Details

Logically, it should not be possible to have a graph class of "DAG" or
"PDAG" that has cycles, but in case the user modified the graph after
creation in some unforeseen way that could have introduced cycles, this
function allows to force a check of acyclicity, if needed.

## See also

Other queries:
[`ancestors()`](https://frederikfabriciusbjerre.github.io/caugi/reference/ancestors.md),
[`children()`](https://frederikfabriciusbjerre.github.io/caugi/reference/children.md),
[`descendants()`](https://frederikfabriciusbjerre.github.io/caugi/reference/descendants.md),
[`edge_types()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edge_types.md),
[`edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edges.md),
[`exogenous()`](https://frederikfabriciusbjerre.github.io/caugi/reference/exogenous.md),
[`is_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_caugi.md),
[`is_cpdag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_cpdag.md),
[`is_dag()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_dag.md),
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
cg_acyclic <- caugi(
  A %-->% B,
  B %-->% C,
  class = "DAG"
)
is_acyclic(cg_acyclic) # TRUE
#> [1] TRUE
cg_cyclic <- caugi(
  A %-->% B,
  B %-->% C,
  C %-->% A,
  class = "UNKNOWN"
)
is_acyclic(cg_cyclic) # FALSE
#> [1] FALSE
```
