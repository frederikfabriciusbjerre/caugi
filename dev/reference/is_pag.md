# Is the `caugi` graph a PAG?

Checks whether the given graph is a Partial Ancestral Graph: whether
some maximal ancestral graph's Markov equivalence class has exactly
these marks as its invariant marks, with a circle wherever the members
disagree.

## Usage

``` r
is_pag(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

A logical value indicating whether the graph is a PAG.

## Details

The check is complete. A member MAG is constructed from the graph, and
[`mag_to_pag()`](https://caugi.org/dev/reference/mag_to_pag.md) must map
it back to exactly this graph. That rejects over-oriented graphs (a
definite mark that is not invariant) and under-oriented ones (a circle
where an invariant mark belongs), which no structural check can detect.
The maximality test is exponential in the worst case, as for
[`is_mag()`](https://caugi.org/dev/reference/is_mag.md).

Building a graph with `class = "PAG"` runs the same check, so there is
no `force_check` argument: the class is a guarantee.

## References

Zhang, J. (2008). On the completeness of orientation rules for causal
discovery in the presence of latent confounders and selection bias.
*Artificial Intelligence*, 172(16-17), 1873-1896.

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
is_pag(mag_to_pag(caugi(A %-->% B, C %-->% B, class = "AG"))) # TRUE
#> [1] TRUE

# Over-oriented: with A and C non-adjacent, whether B is a collider differs
# between members, so these marks are not invariant.
is_pag(caugi(A %o->% B, B %o-o% C, class = "UNKNOWN")) # FALSE
#> [1] FALSE
```
