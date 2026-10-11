# Get connected components of a graph

Partition a graph into maximal weakly or strongly connected components.
This query supports every graph class, including cyclic graphs of class
`"UNKNOWN"`.

## Usage

``` r
components(cg, mode = c("weak", "strong"))
```

## Arguments

- cg:

  A `caugi` object.

- mode:

  Character; `"weak"` (default) or `"strong"`. Weak connectivity ignores
  edge directions and includes all edge types. Strong connectivity uses
  only fully directed edges: every node in a component can reach every
  other node by following directed edges. Undirected, bidirected, and
  partial edges are ignored in strong mode.

## Value

A list of character vectors, one per component. Nodes within each
component follow the graph's node order, and components are ordered by
their first node in that order. Isolated nodes form singleton
components. An empty graph returns
[`list()`](https://rdrr.io/r/base/list.html).

## Details

Every strong component of a DAG is a singleton. Strong components
describe mutual directed reachability, whereas
[`districts()`](https://caugi.org/reference/districts.md) describe
connectivity through bidirected edges.

## See also

Other queries:
[`ancestors()`](https://caugi.org/reference/ancestors.md),
[`anteriors()`](https://caugi.org/reference/anteriors.md),
[`children()`](https://caugi.org/reference/children.md),
[`descendants()`](https://caugi.org/reference/descendants.md),
[`districts()`](https://caugi.org/reference/districts.md),
[`edge_types()`](https://caugi.org/reference/edge_types.md),
[`edges()`](https://caugi.org/reference/edges.md),
[`exogenous()`](https://caugi.org/reference/exogenous.md),
[`is_acyclic()`](https://caugi.org/reference/is_acyclic.md),
[`is_admg()`](https://caugi.org/reference/is_admg.md),
[`is_ag()`](https://caugi.org/reference/is_ag.md),
[`is_caugi()`](https://caugi.org/reference/is_caugi.md),
[`is_cpdag()`](https://caugi.org/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/reference/is_empty_caugi.md),
[`is_mag()`](https://caugi.org/reference/is_mag.md),
[`is_mpdag()`](https://caugi.org/reference/is_mpdag.md),
[`is_pdag()`](https://caugi.org/reference/is_pdag.md),
[`is_simple()`](https://caugi.org/reference/is_simple.md),
[`is_ug()`](https://caugi.org/reference/is_ug.md),
[`m_separated()`](https://caugi.org/reference/m_separated.md),
[`markov_blanket()`](https://caugi.org/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/reference/neighbors.md),
[`nodes()`](https://caugi.org/reference/nodes.md),
[`parents()`](https://caugi.org/reference/parents.md),
[`posteriors()`](https://caugi.org/reference/posteriors.md),
[`same_nodes()`](https://caugi.org/reference/same_nodes.md),
[`spouses()`](https://caugi.org/reference/spouses.md),
[`subgraph()`](https://caugi.org/reference/subgraph.md),
[`topological_sort()`](https://caugi.org/reference/topological_sort.md)

## Examples

``` r
cg <- caugi(A %-->% B, C %-->% B, D, class = "DAG")
components(cg) # list(c("A", "B", "C"), "D")
#> [[1]]
#> [1] "A" "C" "B"
#> 
#> [[2]]
#> [1] "D"
#> 
components(cg, mode = "strong") # Four singleton components
#> [[1]]
#> [1] "A"
#> 
#> [[2]]
#> [1] "C"
#> 
#> [[3]]
#> [1] "B"
#> 
#> [[4]]
#> [1] "D"
#> 

cyclic <- caugi(
  A %-->% B, B %-->% C, C %-->% A, C %-->% D,
  class = "UNKNOWN"
)
components(cyclic, mode = "strong") # list(c("A", "B", "C"), "D")
#> [[1]]
#> [1] "A" "B" "C"
#> 
#> [[2]]
#> [1] "D"
#> 
```
