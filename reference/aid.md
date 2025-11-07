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

A list containing the score (normalized) and the count.

## See also

Other metrics:
[`hd()`](https://frederikfabriciusbjerre.github.io/caugi/reference/hd.md),
[`shd()`](https://frederikfabriciusbjerre.github.io/caugi/reference/shd.md)
