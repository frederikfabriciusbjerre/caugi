# Get edges of a `caugi`.

Get edges of a `caugi`.

## Usage

``` r
edges(cg)

E(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

A `data.table` with columns `from`, `edge`, and `to`.

## See also

Other queries:
[`ancestors()`](https://caugi.org/reference/ancestors.md),
[`children()`](https://caugi.org/reference/children.md),
[`descendants()`](https://caugi.org/reference/descendants.md),
[`districts()`](https://caugi.org/reference/districts.md),
[`edge_types()`](https://caugi.org/reference/edge_types.md),
[`exogenous()`](https://caugi.org/reference/exogenous.md),
[`is_acyclic()`](https://caugi.org/reference/is_acyclic.md),
[`is_admg()`](https://caugi.org/reference/is_admg.md),
[`is_caugi()`](https://caugi.org/reference/is_caugi.md),
[`is_cpdag()`](https://caugi.org/reference/is_cpdag.md),
[`is_dag()`](https://caugi.org/reference/is_dag.md),
[`is_empty_caugi()`](https://caugi.org/reference/is_empty_caugi.md),
[`is_pdag()`](https://caugi.org/reference/is_pdag.md),
[`is_ug()`](https://caugi.org/reference/is_ug.md),
[`m_separated()`](https://caugi.org/reference/m_separated.md),
[`markov_blanket()`](https://caugi.org/reference/markov_blanket.md),
[`neighbors()`](https://caugi.org/reference/neighbors.md),
[`nodes()`](https://caugi.org/reference/nodes.md),
[`parents()`](https://caugi.org/reference/parents.md),
[`same_nodes()`](https://caugi.org/reference/same_nodes.md),
[`spouses()`](https://caugi.org/reference/spouses.md),
[`subgraph()`](https://caugi.org/reference/subgraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  B %-->% C,
  D,
  class = "DAG"
)
edges(cg) # returns the data.table with columns from, edge, to
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    -->      B
#> 2:      B    -->      C
```
