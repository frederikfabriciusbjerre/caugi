# Enumerate all DAGs in a Markov equivalence class

Given a PDAG, enumerate every Directed Acyclic Graph (DAG) in its Markov
equivalence class – i.e. every acyclic orientation of the undirected
edges that introduces no new v-structures.

## Usage

``` r
enumerate_dags(cg)
```

## Arguments

- cg:

  A `caugi` object of class `"PDAG"` or `"MPDAG"`.

## Value

A list of `caugi` objects of class `"DAG"`, one per DAG in the MEC.

## Details

Implements the recursive listing algorithm of Chickering (2002). The
input is normalized via
[`meek_closure()`](https://caugi.org/dev/reference/meek_closure.md) so
any background-knowledge orientations are preserved and propagated
before enumeration. The number of returned DAGs can grow
super-exponentially in the size of the chain components; use
[`count_dags()`](https://caugi.org/dev/reference/count_dags.md) first to
size the problem.

## References

Chickering, D. M. (2002). "Learning Equivalence Classes of
Bayesian-Network Structures". *Journal of Machine Learning Research*,
2:445–498.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`count_dags()`](https://caugi.org/dev/reference/count_dags.md),
[`dag_from_pdag()`](https://caugi.org/dev/reference/dag_from_pdag.md),
[`exogenize()`](https://caugi.org/dev/reference/exogenize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/dev/reference/meek_closure.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/dev/reference/normalize_latent_structure.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
pdag <- caugi(
  A %---% B,
  B %---% C,
  class = "PDAG"
)
dags <- enumerate_dags(pdag)
length(dags) # 3
#> [1] 3
```
