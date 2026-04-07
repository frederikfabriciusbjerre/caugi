# Normalize latent structure in a DAG

Normalizes a DAG with latent variables while preserving the induced
marginal model over the observed variables. This is done by:

\(1\) exogenizing all latent nodes (making them parentless), (2)
removing exogenous latent nodes with at most one child, and (3) removing
exogenous latent nodes whose child sets are strict subsets of another
latent node's child set.

This corresponds to Lemmas 1–3 in Evans (2016).

## Usage

``` r
normalize_latent_structure(cg, latents)
```

## Arguments

- cg:

  A `caugi` object of class "DAG".

- latents:

  Character vector of latent node names.

## Value

A `caugi` object of class "DAG".

## References

Evans, R. J. (2016). Graphs for margins of Bayesian networks.
Scandinavian Journal of Statistics, 43(3), 625–648.
[doi:10.1111/sjos.12194](https://doi.org/10.1111/sjos.12194)

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/dev/reference/meek_closure.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
dag <- caugi(
  A %-->% U,
  U %-->% X + Y,
  class = "DAG"
)

normalize_latent_structure(dag, latents = "U")
#> <caugi object; 4 nodes, 4 edges; simple: TRUE; session=0x560f317abde0>
#>   graph_class: DAG
#>   nodes: A, U, X, Y
#>   edges: A-->X, A-->Y, U-->X, U-->Y

# More complex example with two latents and nested child sets
dag2 <- caugi(
  A %-->% U,
  U %-->% X + Y + Z,
  U2 %-->% Y + Z,
  class = "DAG"
)
normalize_latent_structure(dag2, c("U", "U2"))
#> <caugi object; 5 nodes, 6 edges; simple: TRUE; session=0x560f35f8b100>
#>   graph_class: DAG
#>   nodes: A, U, X, Y, Z
#>   edges: A-->X, A-->Y, A-->Z, U-->X, U-->Y, U-->Z
```
