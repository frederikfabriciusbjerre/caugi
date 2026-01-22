# Hamming Distance

Compute the Hamming Distance between two graphs.

## Usage

``` r
hd(cg1, cg2, normalized = FALSE)
```

## Arguments

- cg1:

  A `caugi` object.

- cg2:

  A `caugi` object.

- normalized:

  Logical; if `TRUE`, returns the normalized Hamming Distance.

## Value

An integer representing the Hamming Distance between the two graphs, if
`normalized = FALSE`, or a numeric between 0 and 1 if
`normalized = TRUE`.

## See also

Other metrics: [`aid()`](https://caugi.org/dev/reference/aid.md),
[`shd()`](https://caugi.org/dev/reference/shd.md)

## Examples

``` r
cg1 <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
cg2 <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
hd(cg1, cg2) # 0
#> [1] 0
```
