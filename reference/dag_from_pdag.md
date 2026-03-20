# Extend a PDAG to a DAG using the Dor-Tarsi Algorithm

Given a Partially Directed Acyclic Graph (PDAG), this function attempts
to extend it to a Directed Acyclic Graph (DAG) by orienting the
undirected edges while preserving acyclicity and all existing directed
edges. The procedure implements the Dor-Tarsi algorithm.

If the PDAG cannot be consistently extended to a DAG, the function will
raise an error.

## Usage

``` r
dag_from_pdag(PDAG)
```

## Arguments

- PDAG:

  A `caugi` object of class `"PDAG"`.

## Value

A `caugi` object of class `"DAG"` representing a DAG extension of the
input PDAG.

## References

Dor, D., & Tarsi, M. (1992). "A simple algorithm to construct a
consistent extension of a partially directed acyclic graph".

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/reference/condition_marginalize.md),
[`exogenize()`](https://caugi.org/reference/exogenize.md),
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/reference/meek_closure.md),
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/reference/normalize_latent_structure.md),
[`skeleton()`](https://caugi.org/reference/skeleton.md)

## Examples

``` r
PDAG <- caugi(
  A %---% B,
  B %---% C,
  class = "PDAG"
)
DAG <- dag_from_pdag(PDAG)
edges(DAG)
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      B    -->      A
#> 2:      C    -->      B
```
