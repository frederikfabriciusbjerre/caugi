# Get descendants of nodes in a `caugi`

Get descendants of nodes in a `caugi`

## Usage

``` r
descendants(cg, nodes = NULL, index = NULL)
```

## Arguments

- cg:

  A `caugi` object.

- nodes:

  A vector of node names, a vector of unquoted node names, or an
  expression combining these with `+` and
  [`c()`](https://rdrr.io/r/base/c.html).

- index:

  A vector of node indexes.

## Value

Either a character vector of node names (if a single node is requested)
or a list of character vectors (if multiple nodes are requested).

## See also

Other queries:
[`ancestors()`](https://frederikfabriciusbjerre.github.io/caugi/reference/ancestors.md),
[`children()`](https://frederikfabriciusbjerre.github.io/caugi/reference/children.md),
[`edge_types()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edge_types.md),
[`edges()`](https://frederikfabriciusbjerre.github.io/caugi/reference/edges.md),
[`exogenous()`](https://frederikfabriciusbjerre.github.io/caugi/reference/exogenous.md),
[`is_acyclic()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_acyclic.md),
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
cg <- caugi(
  A %-->% B,
  B %-->% C,
  class = "DAG"
)
descendants(cg, "A") # "B" "C"
#> [1] "B" "C"
descendants(cg, index = 2) # "C"
#> [1] "C"
descendants(cg, "B") # "C"
#> [1] "C"
descendants(cg, c("B", "C"))
#> $B
#> [1] "C"
#> 
#> $C
#> NULL
#> 
#> $B
#> [1] "C"
#>
#> $C
#> NULL
```
