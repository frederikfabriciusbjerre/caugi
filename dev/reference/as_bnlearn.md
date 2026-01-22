# Convert a caugi to a bnlearn network

Convert a caugi to a bnlearn network

## Usage

``` r
as_bnlearn(x)
```

## Arguments

- x:

  A `caugi` object.

## Value

A `bnlearn` DAG.

## See also

Other conversions:
[`as_adjacency()`](https://caugi.org/dev/reference/as_adjacency.md),
[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md),
[`as_dagitty()`](https://caugi.org/dev/reference/as_dagitty.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
g_bn <- as_bnlearn(cg)
```
