# Convert a caugi to an igraph object

Convert a caugi to an igraph object

## Usage

``` r
as_igraph(x, ...)
```

## Arguments

- x:

  A `caugi` object.

- ...:

  Additional arguments passed to
  [`igraph::graph_from_data_frame()`](https://r.igraph.org/reference/graph_from_data_frame.html).

## Value

An `igraph` object representing the same graph structure.

## See also

Other conversions:
[`as_adjacency()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_adjacency.md),
[`as_bnlearn()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_bnlearn.md),
[`as_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_caugi.md),
[`as_dagitty()`](https://frederikfabriciusbjerre.github.io/caugi/reference/as_dagitty.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
ig <- as_igraph(cg)
```
