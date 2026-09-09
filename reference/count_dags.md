# Count DAGs in a Markov equivalence class

Returns the number of DAGs in the Markov equivalence class of a PDAG
without materializing each one. Useful for sizing an enumeration before
calling
[`enumerate_dags()`](https://caugi.org/reference/enumerate_dags.md).

## Usage

``` r
count_dags(cg)
```

## Arguments

- cg:

  A `caugi` object of class `"PDAG"` or `"MPDAG"`.

## Value

A single numeric value, the cardinality of the MEC. Counts above `2^53`
lose integer precision; in practice no realistic PDAG yields a MEC
anywhere near that size.

## References

Chickering, D. M. (2002). "Learning Equivalence Classes of
Bayesian-Network Structures". *Journal of Machine Learning Research*,
2:445–498.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/reference/condition_marginalize.md),
[`dag_from_pdag()`](https://caugi.org/reference/dag_from_pdag.md),
[`enumerate_dags()`](https://caugi.org/reference/enumerate_dags.md),
[`exogenize()`](https://caugi.org/reference/exogenize.md),
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/reference/meek_closure.md),
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/reference/normalize_latent_structure.md),
[`skeleton()`](https://caugi.org/reference/skeleton.md)

## Examples

``` r
pdag <- caugi(
  A %---% B,
  B %---% C,
  class = "PDAG"
)
count_dags(pdag) # 3
#> [1] 3
```
