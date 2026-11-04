# Construct the CPDAG of a DAG

Returns the CPDAG (essential graph) of a DAG's Markov equivalence class:
the DAG's skeleton, with the edges that every DAG in the class orients
the same way directed and the rest undirected.

## Usage

``` r
dag_to_cpdag(cg)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"`.

## Value

A `caugi` object of class `"CPDAG"`.

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
[`pag_to_mag()`](https://caugi.org/dev/reference/pag_to_mag.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
# A chain is equivalent to its reverse and to the fork, so no edge is fixed.
dag_to_cpdag(caugi(A %-->% B, B %-->% C, class = "DAG")) # A --- B --- C
#> <caugi object; 3 nodes, 2 edges; simple: TRUE; session=0x56083e22d8c0>
#>   graph_class: CPDAG
#>   nodes: A, B, C
#>   edges: A---B, B---C

# A v-structure is shared by every member of its class.
dag_to_cpdag(caugi(A %-->% C, B %-->% C, class = "DAG")) # A --> C <-- B
#> <caugi object; 3 nodes, 2 edges; simple: TRUE; session=0x56083a8d1cf0>
#>   graph_class: CPDAG
#>   nodes: A, B, C
#>   edges: A-->C, B-->C
```
