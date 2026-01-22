# Project latent variables from a DAG to an ADMG

Projects out latent (unobserved) variables from a DAG to produce an
Acyclic Directed Mixed Graph (ADMG) over the observed variables.

## Usage

``` r
latent_project(cg, latents)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"`.

- latents:

  Character vector of latent variable names to project out.

## Value

A `caugi` object of class `"ADMG"` containing only the observed
variables.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
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
```
