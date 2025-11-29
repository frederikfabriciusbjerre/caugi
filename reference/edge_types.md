# Get the edge types of a `caugi`.

Get the edge types of a `caugi`.

## Usage

``` r
edge_types(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

A character vector of edge types.

## See also

Other queries:
[`ancestors()`](https://caugi.org/reference/ancestors.md),
[`children()`](https://caugi.org/reference/children.md),
[`descendants()`](https://caugi.org/reference/descendants.md),
[`edges()`](https://caugi.org/reference/edges.md),
[`exogenous()`](https://caugi.org/reference/exogenous.md),
[`is_acyclic()`](https://caugi.org/reference/is_acyclic.md),
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
[`subgraph()`](https://caugi.org/reference/subgraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  B %--o% C,
  C %<->% D,
  D %---% E,
  A %o-o% E,
  class = "UNKNOWN"
)
edge_types(cg) # returns c("-->", "o-o", "--o", "<->", "---")
#> [1] "-->" "--o" "<->" "---" "o-o"
```
