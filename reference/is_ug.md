# Is the `caugi` graph an UG?

Checks if the given `caugi` graph is an undirected graph (UG).

## Usage

``` r
is_ug(cg, force_check = FALSE)
```

## Arguments

- cg:

  A `caugi` object.

- force_check:

  Logical; if `TRUE`, the function will test if the graph is an UG, if
  `FALSE` (default), it will look at the graph class and match it, if
  possible.

## Value

A logical value indicating whether the graph is an UG.

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
[`is_cpdag()`](https://caugi.org/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/reference/is_empty_caugi.md),
[`is_pdag()`](https://caugi.org/reference/is_pdag.md),
[`markov_blanket()`](https://caugi.org/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/reference/neighbors.md),
[`nodes()`](https://caugi.org/reference/nodes.md),
[`parents()`](https://caugi.org/reference/parents.md),
[`same_nodes()`](https://caugi.org/reference/same_nodes.md),
[`subgraph()`](https://caugi.org/reference/subgraph.md)

## Examples

``` r
cg_ug_class <- caugi(
  A %---% B,
  class = "UG"
)
is_ug(cg_ug_class) # TRUE
#> [1] TRUE
cg_not_ug <- caugi(
  A %-->% B,
  class = "DAG"
)
is_ug(cg_not_ug) # FALSE
#> [1] FALSE
```
