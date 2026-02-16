# Is the `caugi` graph simple?

Checks if the given `caugi` graph is simple (no self-loops and no
parallel edges).

## Usage

``` r
is_simple(cg, force_check = FALSE)
```

## Arguments

- cg:

  A `caugi` object.

- force_check:

  Logical; if `TRUE`, force a check against the compiled graph
  representation. If `FALSE` (default), return the declared `simple`
  property.

## Value

A logical value indicating whether the graph is simple.

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
[`subgraph()`](https://caugi.org/dev/reference/subgraph.md),
[`topological_sort()`](https://caugi.org/dev/reference/topological_sort.md)

## Examples

``` r
cg_simple <- caugi(
  A %-->% B,
  class = "DAG"
)
is_simple(cg_simple) # TRUE
#> [1] TRUE

cg_nonsimple <- caugi(
  A %-->% B,
  A %<->% B,
  class = "UNKNOWN",
  simple = FALSE
)
is_simple(cg_nonsimple) # FALSE
#> [1] FALSE
```
