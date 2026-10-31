# Construct a MAG from a PAG

Returns one maximal ancestral graph from the Markov equivalence class
that the PAG represents. Every member encodes the same conditional
independences.

## Usage

``` r
pag_to_mag(cg)
```

## Arguments

- cg:

  A `caugi` object of class `"PAG"`.

## Value

A `caugi` object of class `"AG"` that is a MAG in the represented Markov
equivalence class.

## Details

The member is the one Zhang's construction (2008, Theorem 2) selects: a
circle opposite an arrowhead becomes a tail and a circle opposite a tail
an arrowhead, so `o->` and `--o` both become `-->`, and the `o-o`
subgraph is oriented into a DAG with no unshielded colliders. That
choice always gives a member, but other members can resolve the same
circles differently: `A o-> B <-o C` has both `A --> B <-- C` and
`A <-> B <-> C`.

## References

Zhang, J. (2008). On the completeness of orientation rules for causal
discovery in the presence of latent confounders and selection bias.
*Artificial Intelligence*, 172(16-17), 1873-1896.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`count_dags()`](https://caugi.org/dev/reference/count_dags.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`dag_to_pag()`](https://caugi.org/dev/reference/dag_to_pag.md),
[`enumerate_dags()`](https://caugi.org/dev/reference/enumerate_dags.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`mag_to_pag()`](https://caugi.org/dev/reference/mag_to_pag.md),
[`meek_closure()`](https://caugi.org/dev/reference/meek_closure.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/dev/reference/normalize_latent_structure.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
pag <- caugi(A %-->% B, C %o->% A, D %o->% A, class = "PAG")
pag_to_mag(pag)
#> <caugi object; 4 nodes, 3 edges; simple: TRUE; session=0x56088829ec60>
#>   graph_class: AG
#>   nodes: A, C, D, B
#>   edges: A-->B, C-->A, D-->A

# An all-circle graph is oriented into a DAG with no unshielded colliders.
pag_to_mag(caugi(A %o-o% B, A %o-o% C, C %o-o% D, class = "PAG"))
#> <caugi object; 4 nodes, 3 edges; simple: TRUE; session=0x5608835e77d0>
#>   graph_class: AG
#>   nodes: A, C, B, D
#>   edges: A-->B, C-->A, D-->C
```
