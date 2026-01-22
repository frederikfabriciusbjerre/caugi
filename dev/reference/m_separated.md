# M-separation test for AGs and ADMGs

Test whether two sets of nodes are m-separated given a conditioning set
in an ancestral graph (AG) or an ADMG.

M-separation generalizes d-separation to AGs/ADMGs and applies to DAGs.

## Usage

``` r
m_separated(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
)
```

## Arguments

- cg:

  A `caugi` object of class AG, ADMG, or DAG.

- X, Y, Z:

  Node selectors: character vector of names, unquoted expression
  (supports `+` and [`c()`](https://rdrr.io/r/base/c.html)), or `NULL`.
  Use `*_index` to pass 1-based indices. If `Z` is `NULL` or missing, no
  nodes are conditioned on.

- X_index, Y_index, Z_index:

  Optional numeric 1-based indices (exclusive with `X`,`Y`,`Z`
  respectively).

## Value

A logical value; `TRUE` if `X` and `Y` are m-separated given `Z`.

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
# Classic confounding example
cg <- caugi(
  L %-->% X,
  X %-->% Y,
  L %-->% Y,
  class = "ADMG"
)
m_separated(cg, X = "X", Y = "Y") # FALSE (connected via L)
#> [1] FALSE
m_separated(cg, X = "X", Y = "Y", Z = "L") # TRUE (L blocks the path)
#> [1] FALSE
```
