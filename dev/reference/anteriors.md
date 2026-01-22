# Get anteriors of nodes in a `caugi`

Get the anterior set of nodes in a graph. The anterior set (Richardson
and Spirtes, 2002) includes all nodes reachable by following paths where
every edge is either undirected or directed toward the target node.

For DAGs, the anterior set equals the ancestor set (since there are no
undirected edges). For PDAGs, it includes both ancestors and nodes
reachable via undirected edges.

## Usage

``` r
anteriors(cg, nodes = NULL, index = NULL)
```

## Arguments

- cg:

  A `caugi` object of class DAG or PDAG.

- nodes:

  A vector of node names, a vector of unquoted node names, or an
  expression combining these with `+` and
  [`c()`](https://rdrr.io/r/base/c.html).

- index:

  A vector of node indexes.

## Value

Either a character vector of node names (if a single node is requested)
or a list of character vectors (if multiple nodes are requested).

## References

Richardson, T. and Spirtes, P. (2002). Ancestral graph Markov models.
*The Annals of Statistics*, 30(4):962-1030.

## See also

Other queries:
[`ancestors()`](https://caugi.org/dev/reference/ancestors.md),
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
# PDAG example with directed and undirected edges
cg <- caugi(
  A %-->% B %---% C,
  B %-->% D,
  class = "PDAG"
)
anteriors(cg, "A") # NULL (no anteriors)
#> NULL
anteriors(cg, "C") # A, B
#> [1] "A" "B"
anteriors(cg, "D") # A, B, C
#> [1] "A" "B" "C"

# For DAGs, anteriors equals ancestors
cg_dag <- caugi(
  A %-->% B %-->% C,
  class = "DAG"
)
anteriors(cg_dag, "C") # A, B
#> [1] "A" "B"
```
