# Marginalize and/or condition on variables in an ancestral graph (AG)

Marginalize variables out of an AG, and/or condition on variables.
Depending on the structure, it could produce a graph with directed,
bidirected, and undirected edges.

## Usage

``` r
condition_marginalize(cg, cond_vars = NULL, marg_vars = NULL)
```

## Arguments

- cg:

  A `caugi` ancestral graph of class `"AG"`.

- cond_vars:

  Character vector of nodes to condition on.

- marg_vars:

  Character vector of nodes to marginalize over.

## Value

A `caugi` object of class `"AG"`.

## References

Definition 4.2.1 in Thomas Richardson. Peter Spirtes. "Ancestral graph
Markov models." Ann. Statist. 30 (4) 962 - 1030, August 2002.
[doi:10.1214/aos/1031689015](https://doi.org/10.1214/aos/1031689015)

## See also

Other operations:
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
mg <- caugi(
  U %-->% X + Y,
  A %-->% X,
  B %-->% Y,
  class = "DAG"
)

condition_marginalize(mg, marg_vars = "U") # ADMG
#> <caugi object; 4 nodes, 3 edges; simple: TRUE; built: TRUE; ptr=0x5558a50f6290>
#>   graph_class: AG
#>   nodes: A, B, X, Y
#>   edges: A-->X, B-->Y, X<->Y
condition_marginalize(mg, cond_vars = "U") # DAG
#> <caugi object; 4 nodes, 2 edges; simple: TRUE; built: TRUE; ptr=0x5558a4bfcca0>
#>   graph_class: AG
#>   nodes: A, B, X, Y
#>   edges: A-->X, B-->Y
```
