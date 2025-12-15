# Convert a caugi to a dagitty graph

Convert a caugi to a dagitty graph

## Usage

``` r
as_dagitty(x)
```

## Arguments

- x:

  A `caugi` object.

## Value

A `dagitty` object.

## See also

Other conversions:
[`as_adjacency()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_adjacency.md),
[`as_bnlearn()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_bnlearn.md),
[`as_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_caugi.md),
[`as_igraph()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
g_dg <- as_dagitty(cg)
```
