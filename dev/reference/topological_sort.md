# Get a topological ordering of a DAG

Returns a topological ordering of the nodes in a DAG. For every directed
edge u -\> v in the graph, u will appear before v in the returned
ordering.

## Usage

``` r
topological_sort(cg)
```

## Arguments

- cg:

  A `caugi` object of class DAG.

## Value

A character vector of node names in topological order.

## See also

Other queries:
[`ancestors()`](https://caugi.org/dev/reference/ancestors.md),
[`anteriors()`](https://caugi.org/dev/reference/anteriors.md),
[`children()`](https://caugi.org/dev/reference/children.md),
[`descendants()`](https://caugi.org/dev/reference/descendants.md),
[`districts()`](https://caugi.org/dev/reference/districts.md),
[`edge_types()`](https://caugi.org/dev/reference/edge_types.md),
[`edges()`](https://caugi.org/dev/reference/edges.md),
[`exogenous()`](https://caugi.org/dev/reference/exogenous.md),
[`is_acyclic()`](https://caugi.org/dev/reference/is_acyclic.md),
[`is_admg()`](https://caugi.org/dev/reference/is_admg.md),
[`is_ag()`](https://caugi.org/dev/reference/is_ag.md),
[`is_caugi()`](https://caugi.org/dev/reference/is_caugi.md),
[`is_cpdag()`](https://caugi.org/dev/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/dev/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/dev/reference/is_empty_caugi.md),
[`is_mag()`](https://caugi.org/dev/reference/is_mag.md),
[`is_pdag()`](https://caugi.org/dev/reference/is_pdag.md),
[`is_ug()`](https://caugi.org/dev/reference/is_ug.md),
[`m_separated()`](https://caugi.org/dev/reference/m_separated.md),
[`markov_blanket()`](https://caugi.org/dev/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/dev/reference/neighbors.md),
[`nodes()`](https://caugi.org/dev/reference/nodes.md),
[`parents()`](https://caugi.org/dev/reference/parents.md),
[`same_nodes()`](https://caugi.org/dev/reference/same_nodes.md),
[`spouses()`](https://caugi.org/dev/reference/spouses.md),
[`subgraph()`](https://caugi.org/dev/reference/subgraph.md)

## Examples

``` r
# Simple DAG: A -> B -> C
cg <- caugi(
  A %-->% B,
  B %-->% C,
  class = "DAG"
)
topological_sort(cg) # Returns c("A", "B", "C") or equivalent valid ordering
#> [1] "A" "B" "C"

# DAG with multiple valid orderings
cg2 <- caugi(
  A %-->% C,
  B %-->% C,
  class = "DAG"
)
# Could return c("A", "B", "C") or c("B", "A", "C")
topological_sort(cg2)
#> [1] "B" "A" "C"
```
