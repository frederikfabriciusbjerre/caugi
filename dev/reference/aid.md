# Adjustment Identification Distance

Compute the Adjustment Identification Distance (AID) between two graphs
using the `gadjid` Rust package.

## Usage

``` r
aid(truth, guess, type = c("oset", "ancestor", "parent"), normalized = TRUE)
```

## Arguments

- truth:

  A `caugi` object.

- guess:

  A `caugi` object.

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
