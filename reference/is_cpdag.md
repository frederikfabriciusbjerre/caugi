# Is the `caugi` graph a CPDAG?

Checks if the given `caugi` graph is a Complete Partially Directed
Acyclic Graph (CPDAG).

## Usage

``` r
is_cpdag(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

A logical value indicating whether the graph is a CPDAG.

## See also

Other queries:
[`ancestors()`](https://caugi.org/reference/ancestors.md),
[`children()`](https://caugi.org/reference/children.md),
[`descendants()`](https://caugi.org/reference/descendants.md),
[`edge_types()`](https://caugi.org/reference/edge_types.md),
[`edges()`](https://caugi.org/reference/edges.md),
[`exogenous()`](https://caugi.org/reference/exogenous.md),
[`is_acyclic()`](https://caugi.org/reference/is_acyclic.md),
[`is_caugi()`](https://caugi.org/reference/is_caugi.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/reference/is_empty_caugi.md),
[`is_pdag()`](https://caugi.org/reference/is_pdag.md),
[`is_ug()`](https://caugi.org/reference/is_ug.md),
[`markov_blanket()`](https://caugi.org/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/reference/neighbors.md),
[`nodes()`](https://caugi.org/reference/nodes.md),
[`parents()`](https://caugi.org/reference/parents.md),
[`same_nodes()`](https://caugi.org/reference/same_nodes.md),
[`subgraph()`](https://caugi.org/reference/subgraph.md)

## Examples

``` r
cg_cpdag <- caugi(
  A %---% B,
  A %-->% C,
  B %-->% C,
  class = "PDAG"
)
is_cpdag(cg_cpdag) # TRUE
#> [1] TRUE

cg_not_cpdag <- caugi(
  A %---% B,
  A %---% C,
  B %-->% C,
  class = "PDAG"
)
is_cpdag(cg_not_cpdag) # FALSE
#> [1] FALSE
```
