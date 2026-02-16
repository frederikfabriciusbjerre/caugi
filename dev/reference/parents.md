# Get parents of nodes in a `caugi`

Get parents of nodes in a graph (nodes with directed edges pointing INTO
the target node). This is equivalent to
`neighbors(cg, nodes, mode = "in")`.

Note that not both nodes and index can be given.

## Usage

``` r
parents(cg, nodes = NULL, index = NULL)
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
[`is_simple()`](https://caugi.org/dev/reference/is_simple.md),
[`is_ug()`](https://caugi.org/dev/reference/is_ug.md),
[`m_separated()`](https://caugi.org/dev/reference/m_separated.md),
[`markov_blanket()`](https://caugi.org/dev/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/dev/reference/neighbors.md),
[`nodes()`](https://caugi.org/dev/reference/nodes.md),
[`same_nodes()`](https://caugi.org/dev/reference/same_nodes.md),
[`spouses()`](https://caugi.org/dev/reference/spouses.md),
[`subgraph()`](https://caugi.org/dev/reference/subgraph.md),
[`topological_sort()`](https://caugi.org/dev/reference/topological_sort.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  B %-->% C,
  class = "DAG"
)
parents(cg, "A") # NULL
#> NULL
parents(cg, index = 2) # "A"
#> [1] "A"
parents(cg, "B") # "A"
#> [1] "A"
parents(cg, c("B", "C"))
#> $B
#> [1] "A"
#> 
#> $C
#> [1] "B"
#> 
#> $B
#> [1] "A"
#>
#> $C
#> [1] "B"
```
