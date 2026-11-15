# Adjustment Identification Distance

Compute the Adjustment Identification Distance (AID) between two graphs.
AID counts how often the adjustment-identification strategy applied to
`cg2` yields a causal inference that is incorrect relative to `cg1`.
Implemented in caugi's Rust backend following Henckel, Würtzen &
Weichwald (2024), <doi:10.48550/arXiv.2402.08616>.

## Usage

``` r
aid(
  cg1,
  cg2,
  type = c("oset", "ancestor", "parent"),
  normalized = TRUE,
  truth,
  guess
)
```

## Arguments

- cg1:

  The true graph, a `caugi` object of class `"DAG"` or `"CPDAG"`.

- cg2:

  The estimated graph, a `caugi` object of class `"DAG"` or `"CPDAG"`.

- type:

  A character string specifying the type of AID to compute. Options are
  `"oset"` (default), `"ancestor"`, and `"parent"`.

- normalized:

  Logical; if `TRUE`, returns the normalized AID. If `FALSE`, returns
  the count.

- truth, guess:

  Deprecated; use `cg1` and `cg2`.

## Value

A numeric representing the AID between the two graphs, if
`normalized = TRUE`, or an integer count if `normalized = FALSE`.

## See also

Other metrics: [`hd()`](https://caugi.org/dev/reference/hd.md),
[`shd()`](https://caugi.org/dev/reference/shd.md)

## Examples

``` r
set.seed(1)
truth <- generate_graph(n = 100, m = 200, class = "DAG")
guess <- generate_graph(n = 100, m = 200, class = "DAG")
aid(truth, guess) # 0.098
#> [1] 0.09808081
```
