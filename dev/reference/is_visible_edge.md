# Is a directed edge in a MAG or PAG visible?

Checks whether the directed edge `from --> to` is *visible* (Zhang 2008,
Definition 8): some node `c` not adjacent to `to` has either an edge
into `from`, or a collider path into `from` whose non-endpoints are all
parents of `to`.

## Usage

``` r
is_visible_edge(cg, from = NULL, to = NULL, from_index = NULL, to_index = NULL)
```

## Arguments

- cg:

  A `caugi` object of class `"AG"` that is a MAG, or of class `"PAG"`.

- from, to:

  Node names. Use `from_index`/`to_index` to pass 1-based indices
  instead.

- from_index, to_index:

  Optional 1-based indices, exclusive with `from` and `to` respectively.

## Value

`TRUE` if the edge `from --> to` is visible, otherwise `FALSE`.

## Details

In a MAG, `from --> to` means `from` is an ancestor of `to` in every DAG
the MAG represents. The effect may run through latent variables, so it
need not be direct. If the edge is visible, no represented DAG has an
inducing path between `from` and `to`, relative to the latent variables,
that is into `from` (Zhang 2008, Lemma 9). If it is invisible, some
represented DAG has a latent common parent of the two (Lemma 10).
Visibility therefore rules out latent confounding of the pair, not
mediation. Maathuis and Colombo (2015) use it in their generalized
back-door criterion.

In a PAG, an edge that meets the same criterion is *definitely visible*:
it is visible in every MAG of the represented class (Zhang 2008, Section
4.2).

Only `-->` edges can be visible, so `FALSE` is returned for any other
edge, for a non-adjacent pair and for the reverse of a directed edge.

## References

Zhang, J. (2008). Causal reasoning with ancestral graphs. *Journal of
Machine Learning Research*, 9, 1437-1474.

Maathuis, M. H. and Colombo, D. (2015). A generalized back-door
criterion. *The Annals of Statistics*, 43(3), 1060-1088.

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
# The `pcalg::visibleEdge()` example MAG.
mag <- caugi(A %-->% B, B %<->% C, B %-->% D, C %-->% D, class = "AG")
is_visible_edge(mag, "A", "B") # FALSE: every other node is adjacent to B
#> [1] FALSE
is_visible_edge(mag, "B", "D") # TRUE: A --> B with A, D non-adjacent
#> [1] TRUE
is_visible_edge(mag, "C", "D") # TRUE: collider path A --> B <-> C
#> [1] TRUE

pag <- caugi(A %-->% B, C %o->% A, D %o->% A, C %-->% B, class = "PAG")
is_visible_edge(pag, "A", "B") # TRUE: D *-> A with D, B non-adjacent
#> [1] TRUE
is_visible_edge(pag, "C", "B") # FALSE
#> [1] FALSE
```
