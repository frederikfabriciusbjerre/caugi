# Get ancestors of nodes in a `caugi`

Get ancestors of nodes in a `caugi`

## Usage

``` r
ancestors(
  cg,
  nodes = NULL,
  index = NULL,
  open = caugi_options("use_open_graph_definition")
)
```

## Arguments

- cg:

  A `caugi` object.

- nodes:

  A character vector of node names.

- index:

  A vector of node indexes.

- open:

  Boolean. Determines how the graph is interpreted when retrieving
  ancestors. Default is taken from
  `caugi_options("use_open_graph_definition")`, which by default is
  TRUE.

## Value

Either a character vector of node names (if a single node is requested)
or a list of character vectors (if multiple nodes are requested).

## See also

Other queries:
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
[`parents()`](https://caugi.org/dev/reference/parents.md),
[`posteriors()`](https://caugi.org/dev/reference/posteriors.md),
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
ancestors(cg, "A") # NULL
#> NULL
ancestors(cg, "A", open = FALSE) # A
#> [1] "A"
ancestors(cg, index = 2) # "A"
#> [1] "A"
ancestors(cg, "B") # "A"
#> [1] "A"
ancestors(cg, c("B", "C"))
#> $B
#> [1] "A"
#> 
#> $C
#> [1] "A" "B"
#> 
#> $B
#> [1] "A"
#>
#> $C
#> [1] "A" "B"
```
