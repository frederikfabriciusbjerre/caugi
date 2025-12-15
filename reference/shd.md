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

An integer representing the Hamming Distance between the two graphs, if
`normalized = FALSE`, or a numeric between 0 and 1 if
`normalized = TRUE`.

## See also

Other metrics:
[`aid()`](https://frederikfabriciusbjerre.github.io/caugi/reference/aid.md),
[`hd()`](https://frederikfabriciusbjerre.github.io/caugi/reference/hd.md)

## Examples

``` r
cg1 <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
cg2 <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
shd(cg1, cg2) # 1
#> [1] 1
```
