# Convert a caugi to an adjacency matrix

Does not take other edge types than the one found in a PDAG.

## Usage

``` r
as_adjacency(x)
```

## Arguments

- x:

  A `caugi` object.

## Value

An integer 0/1 adjacency matrix with row/col names.

## See also

Other conversions:
[`as_bnlearn()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_bnlearn.md),
[`as_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_caugi.md),
[`as_dagitty()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_dagitty.md),
[`as_igraph()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
adj <- as_adjacency(cg)
```
