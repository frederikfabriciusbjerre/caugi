# Project latent variables out of a DAG or an ADMG

Projects out latent (unobserved) variables from a DAG or an ADMG to
produce an Acyclic Directed Mixed Graph (ADMG) over the observed
variables.

## Usage

``` r
latent_project(cg, latents)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"` or `"ADMG"`.

- latents:

  Character vector of latent variable names to project out.

## Value

A `caugi` object of class `"ADMG"` containing only the observed
variables.

## Details

In the projection, `a --> b` when the graph has a directed path from `a`
to `b` whose inner nodes are all latent, and `a <-> b` when it has a
path between them whose inner nodes are all latent non-colliders, with
an arrowhead at both `a` and `b`. Projecting out latents one set at a
time gives the same ADMG as projecting them out together.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`count_dags()`](https://caugi.org/dev/reference/count_dags.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`dag_to_cpdag()`](https://caugi.org/dev/reference/dag_to_cpdag.md),
[`dag_to_mpdag()`](https://caugi.org/dev/reference/dag_to_mpdag.md),
[`dag_to_pag()`](https://caugi.org/dev/reference/dag_to_pag.md),
[`enumerate_dags()`](https://caugi.org/dev/reference/enumerate_dags.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`mag_to_pag()`](https://caugi.org/dev/reference/mag_to_pag.md),
[`meek_closure()`](https://caugi.org/dev/reference/meek_closure.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/dev/reference/normalize_latent_structure.md),
[`pag_to_mag()`](https://caugi.org/dev/reference/pag_to_mag.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
# DAG with latent confounder U
dag <- caugi(
  U %-->% X,
  U %-->% Y,
  X %-->% Y,
  class = "DAG"
)

# Project out the latent variable
admg <- latent_project(dag, latents = "U")
# Result: X -> Y, X <-> Y (children of U become bidirected-connected)
edges(admg)
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      X    -->      Y
#> 2:      X    <->      Y

# DAG with directed path through latent
dag2 <- caugi(
  X %-->% L,
  L %-->% Y,
  class = "DAG"
)

# Project out the latent variable
admg2 <- latent_project(dag2, latents = "L")
# Result: X -> Y (directed path X -> L -> Y becomes X -> Y)
edges(admg2)
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      X    -->      Y

# ADMG: a bidirected edge into a latent non-collider carries over
admg3 <- caugi(A %<->% L, L %-->% B, class = "ADMG")
edges(latent_project(admg3, latents = "L")) # A <-> B
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    <->      B
```
