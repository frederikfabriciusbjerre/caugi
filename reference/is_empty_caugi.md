# Is the `caugi` graph empty?

Checks if the given `caugi` graph is empty (has no nodes).

## Usage

``` r
is_empty_caugi(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

A logical value indicating whether the graph is empty.

## See also

Other queries:
[`ancestors()`](https://caugi.org/reference/ancestors.md),
[`children()`](https://caugi.org/reference/children.md),
[`descendants()`](https://caugi.org/reference/descendants.md),
[`districts()`](https://caugi.org/reference/districts.md),
[`edge_types()`](https://caugi.org/reference/edge_types.md),
[`edges()`](https://caugi.org/reference/edges.md),
[`exogenous()`](https://caugi.org/reference/exogenous.md),
[`is_acyclic()`](https://caugi.org/reference/is_acyclic.md),
[`is_admg()`](https://caugi.org/reference/is_admg.md),
[`is_caugi()`](https://caugi.org/reference/is_caugi.md),
[`is_cpdag()`](https://caugi.org/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_pdag()`](https://caugi.org/reference/is_pdag.md),
[`is_ug()`](https://caugi.org/reference/is_ug.md),
[`m_separated()`](https://caugi.org/reference/m_separated.md),
[`markov_blanket()`](https://caugi.org/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/reference/neighbors.md),
[`nodes()`](https://caugi.org/reference/nodes.md),
[`parents()`](https://caugi.org/reference/parents.md),
[`same_nodes()`](https://caugi.org/reference/same_nodes.md),
[`spouses()`](https://caugi.org/reference/spouses.md),
[`subgraph()`](https://caugi.org/reference/subgraph.md),
[`topological_sort()`](https://caugi.org/reference/topological_sort.md)

## Examples

``` r
cg_empty <- caugi(class = "DAG")
is_empty_caugi(cg_empty) # TRUE
#> [1] TRUE
cg_non_empty <- caugi(
  A %-->% B,
  class = "DAG"
)
is_empty_caugi(cg_non_empty) # FALSE
#> [1] FALSE

cg_no_edges_but_has_nodes <- caugi(
  A, B,
  class = "DAG"
)
is_empty_caugi(cg_no_edges_but_has_nodes) # FALSE
#> [1] FALSE
```
