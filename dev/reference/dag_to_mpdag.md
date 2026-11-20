# Construct the MPDAG of a DAG and background knowledge

Returns the DAGs Markov equivalent to `cg` that agree with `bk`, as
`orient(dag_to_cpdag(cg), bk)`. Errors with class `caugi_inconsistent`
if `cg` itself does not agree with `bk`.

## Usage

``` r
dag_to_mpdag(cg, bk)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"`.

- bk:

  Background knowledge, made by
  [`knowledge()`](https://caugi.org/dev/reference/knowledge.md).

## Value

A `caugi` object of class `"MPDAG"`, or `"DAG"` if the knowledge orients
every edge.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`count_dags()`](https://caugi.org/dev/reference/count_dags.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`dag_to_cpdag()`](https://caugi.org/dev/reference/dag_to_cpdag.md),
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
dag <- caugi(A %-->% B, B %-->% C, class = "DAG")
dag_to_mpdag(dag, knowledge(!(C %-->% B))) # A --- B --> C
#> <caugi object; 3 nodes, 2 edges; simple: TRUE; session=0x5b61ff287d70>
#>   graph_class: MPDAG
#>   nodes: A, B, C
#>   edges: A---B, B-->C
```
