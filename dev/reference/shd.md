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
`normalized = FALSE`, or that count divided by the number of node pairs
if `normalized = TRUE`. The normalized SHD is between 0 and 1 unless a
pair has more than one edge.

## Details

Each edge counts: a missing, extra or differently typed edge adds

1.  Between a pair of nodes, the SHD counts the fewest edges to add,
    remove or change to turn one graph's edges into the other's. So
    `A --> B, A <-> B`, as
    [`latent_project()`](https://caugi.org/dev/reference/latent_project.md)
    can give, is 1 from `A --> B`, 1 from `A --> B, A --- B` and 2 from
    no edge.

## See also

Other metrics: [`aid()`](https://caugi.org/dev/reference/aid.md),
[`hd()`](https://caugi.org/dev/reference/hd.md)

## Examples

``` r
cg1 <- caugi(A %-->% B %-->% C, D %-->% C, class = "DAG")
cg2 <- caugi(A %-->% B %-->% C, D %---% C, class = "PDAG")
shd(cg1, cg2) # 1
#> [1] 1
```
