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
[`as_adjacency()`](https://caugi.org/dev/reference/as_adjacency.md),
[`as_bnlearn()`](https://caugi.org/dev/reference/as_bnlearn.md),
[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
g_dg <- as_dagitty(cg)
```
