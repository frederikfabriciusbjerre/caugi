# Convert a caugi to an adjacency matrix

Only supports the edge types found in a PDAG (`-->` and `---`). A `---`
edge is written as `1` in both directions, so other symmetric edges such
as `<->` are rejected rather than encoded the same way.

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
[`as_bnlearn()`](https://caugi.org/dev/reference/as_bnlearn.md),
[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md),
[`as_dagitty()`](https://caugi.org/dev/reference/as_dagitty.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
adj <- as_adjacency(cg)
```
