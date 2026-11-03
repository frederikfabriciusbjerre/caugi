# Are two graphs Markov equivalent?

Checks whether two DAGs or CPDAGs encode the same conditional
independencies. Two DAGs are Markov equivalent exactly when they share
their skeleton and v-structures (Verma and Pearl, 1990), that is, when
they have the same CPDAG, so a DAG is compared through
[`dag_to_cpdag()`](https://caugi.org/dev/reference/dag_to_cpdag.md) and
a CPDAG as it is.

## Usage

``` r
markov_equivalent(g1, g2)
```

## Arguments

- g1, g2:

  `caugi` objects of class `"DAG"` or `"CPDAG"`.

## Value

`TRUE` if `g1` and `g2` are Markov equivalent, `FALSE` otherwise,
including when their nodes differ.

## References

Verma, T. and Pearl, J. (1990). Equivalence and synthesis of causal
models. In *Proceedings of the Sixth Conference on Uncertainty in
Artificial Intelligence*, 220-227.

## See also

Other queries:
[`ancestors()`](https://caugi.org/dev/reference/ancestors.md),
[`anteriors()`](https://caugi.org/dev/reference/anteriors.md),
[`children()`](https://caugi.org/dev/reference/children.md),
[`components()`](https://caugi.org/dev/reference/components.md),
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
[`is_mpdag()`](https://caugi.org/dev/reference/is_mpdag.md),
[`is_pag()`](https://caugi.org/dev/reference/is_pag.md),
[`is_pdag()`](https://caugi.org/dev/reference/is_pdag.md),
[`is_simple()`](https://caugi.org/dev/reference/is_simple.md),
[`is_ug()`](https://caugi.org/dev/reference/is_ug.md),
[`is_visible_edge()`](https://caugi.org/dev/reference/is_visible_edge.md),
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
chain <- caugi(A %-->% B, B %-->% C, class = "DAG")
fork <- caugi(B %-->% A, B %-->% C, class = "DAG")
collider <- caugi(A %-->% B, C %-->% B, class = "DAG")
markov_equivalent(chain, fork) # TRUE
#> [1] TRUE
markov_equivalent(chain, collider) # FALSE
#> [1] FALSE
```
