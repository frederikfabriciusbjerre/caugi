# Is it a `caugi` graph?

Checks if the given object is a `caugi`. Mostly used internally to
validate inputs.

## Usage

``` r
is_caugi(x, throw_error = FALSE)
```

## Arguments

- x:

  An object to check.

- throw_error:

  Logical; if `TRUE`, throws an error if `x` is not a `caugi`.

## Value

A logical value indicating whether the object is a `caugi`.

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
[`is_cpdag()`](https://caugi.org/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/reference/is_empty_caugi.md),
[`is_mag()`](https://caugi.org/reference/is_mag.md),
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
cg <- caugi(
  A %-->% B,
  class = "DAG"
)

is_caugi(cg) # TRUE
#> [1] TRUE
```
