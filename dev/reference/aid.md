# Adjustment Identification Distance

Compute the Adjustment Identification Distance (AID) between two graphs.
AID counts how often the adjustment-identification strategy applied to
`guess` yields a causal inference that is incorrect relative to `truth`.
Implemented in caugi's Rust backend following Henckel, Würtzen &
Weichwald (2024),
[doi:10.48550/arXiv.2402.08616](https://doi.org/10.48550/arXiv.2402.08616)
.

## Usage

``` r
aid(truth, guess, type = c("oset", "ancestor", "parent"), normalized = TRUE)
```

## Arguments

- truth:

  A `caugi` object of class `"DAG"` or `"CPDAG"`.

- guess:

  A `caugi` object of class `"DAG"` or `"CPDAG"`.

- type:

  A character string specifying the type of AID to compute. Options are
  `"oset"` (default), `"ancestor"`, and `"parent"`.

- normalized:

  Logical; if `TRUE`, returns the normalized AID. If `FALSE`, returns
  the count.

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
aid(truth, guess) # 0.0187
#> [1] 0.1086869
```
