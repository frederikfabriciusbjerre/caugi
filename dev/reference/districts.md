# Get districts (c-components) of an ADMG or AG

Get districts (c-components) for all nodes, or for selected nodes in an
ADMG/AG. A district is a maximal set of nodes connected via bidirected
edges.

## Usage

``` r
districts(cg, nodes = NULL, index = NULL, all = NULL)
```

## Arguments

- cg:

  A `caugi` object of class ADMG or AG.

- nodes:

  Optional character vector of node names. If supplied, returns
  district(s) containing these nodes.

- index:

  Optional numeric vector of 1-based node indices. If supplied, returns
  district(s) containing these indices.

- all:

  Optional logical. If `TRUE`, return all districts explicitly. Cannot
  be combined with `nodes` or `index`.

## Value

If all districts are requested: a list of character vectors, one per
district. If `nodes`/`index` are supplied: either a character vector
(single target) or a named list of character vectors (multiple targets).

## See also

Other queries:
[`ancestors()`](https://caugi.org/dev/reference/ancestors.md),
[`anteriors()`](https://caugi.org/dev/reference/anteriors.md),
[`children()`](https://caugi.org/dev/reference/children.md),
[`descendants()`](https://caugi.org/dev/reference/descendants.md),
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
[`is_simple()`](https://caugi.org/dev/reference/is_simple.md),
[`is_ug()`](https://caugi.org/dev/reference/is_ug.md),
[`m_separated()`](https://caugi.org/dev/reference/m_separated.md),
[`markov_blanket()`](https://caugi.org/dev/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/dev/reference/neighbors.md),
[`nodes()`](https://caugi.org/dev/reference/nodes.md),
[`parents()`](https://caugi.org/dev/reference/parents.md),
[`same_nodes()`](https://caugi.org/dev/reference/same_nodes.md),
[`spouses()`](https://caugi.org/dev/reference/spouses.md),
[`subgraph()`](https://caugi.org/dev/reference/subgraph.md),
[`topological_sort()`](https://caugi.org/dev/reference/topological_sort.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  A %<->% C,
  D %<->% E,
  class = "ADMG"
)
districts(cg)
#> [[1]]
#> [1] "A" "C"
#> 
#> [[2]]
#> [1] "D" "E"
#> 
#> [[3]]
#> [1] "B"
#> 
# Returns list with districts: {A, C}, {B}, {D, E}
districts(cg, nodes = "A") # Returns c("A", "C")
#> [1] "A" "C"
districts(cg, index = c(1, 4))
#> $A
#> [1] "A" "C"
#> 
#> $C
#> [1] "A" "C"
#> 
```
