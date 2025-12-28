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

## Details

The latent projection is a fundamental operation in causal inference for
converting a DAG with latent variables to an ADMG representing the
marginal independence structure over observed variables only.

Uses the vertex elimination algorithm: for each latent vertex v to
eliminate:

1.  Add directed edge p -\> c for all p in Pa(v), c in Ch(v)

2.  Add bidirected edge s \<-\> c for all s in Sib(v), c in Ch(v)

3.  Add bidirected edge a \<-\> b for all pairs a, b in Ch(v)

4.  Remove v

Note: The result may have both directed and bidirected edges between the
same pair of nodes (e.g., X -\> Y and X \<-\> Y), which is valid in
ADMGs.

Note: The resulting ADMG will have nodes re-indexed, preserving the
relative order of observed nodes from the original DAG.

## References

Evans, R. J. (2015). *Graphs for Margins of Bayesian Networks*.
arXiv:1408.1809, Sections 3-4.

## See also

Other operations:
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`skeleton()`](https://caugi.org/reference/skeleton.md)

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
# Result: X -> Y AND X <-> Y (children of U become bidirected-connected)
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
