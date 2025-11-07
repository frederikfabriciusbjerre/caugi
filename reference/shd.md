# Structural Hamming Distance

Compute the Structural Hamming Distance (SHD) between two graphs.

## Usage

``` r
shd(cg1, cg2, normalized = FALSE)
```

## Arguments

- cg1:

  A `caugi` object.

- cg2:

  A `caugi` object.

- normalized:

  Logical; if `TRUE`, returns the normalized SHD.

## Value

An integer representing the SHD between the two graphs.

## See also

Other metrics:
[`aid()`](https://frederikfabriciusbjerre.github.io/caugi/reference/aid.md),
[`hd()`](https://frederikfabriciusbjerre.github.io/caugi/reference/hd.md)
