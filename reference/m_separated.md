# M-separation test for ADMGs

Test whether two sets of nodes are m-separated given a conditioning set
in an ADMG.

M-separation generalizes d-separation to ADMGs.

## Usage

``` r
m_separated(cg, x, y, z = character(0))
```

## Arguments

- cg:

  A `caugi` object of class ADMG or DAG.

- x:

  A character vector of node names (the "source" set).

- y:

  A character vector of node names (the "target" set).

- z:

  A character vector of node names to condition on (default: empty).

## Value

A logical value; `TRUE` if `x` and `y` are m-separated given `z`.

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
[`is_caugi()`](https://caugi.org/reference/is_caugi.md),
[`is_cpdag()`](https://caugi.org/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/reference/is_empty_caugi.md),
[`is_pdag()`](https://caugi.org/reference/is_pdag.md),
[`is_ug()`](https://caugi.org/reference/is_ug.md),
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
# Classic confounding example
cg <- caugi(
  L %-->% X,
  X %-->% Y,
  L %-->% Y,
  class = "ADMG"
)
m_separated(cg, "X", "Y") # FALSE (connected via L)
#> [1] FALSE
m_separated(cg, "X", "Y", "L") # TRUE (L blocks the path)
#> [1] FALSE
```
