# Compute Graph Layout

Computes node coordinates for graph visualization using specified layout
algorithm. If the graph has not been built yet, it will be built
automatically before computing the layout.

## Usage

``` r
caugi_layout(x, method = c("sugiyama"))
```

## Arguments

- x:

  A `caugi` object. Must contain only directed edges for Sugiyama
  layout.

- method:

  Character string specifying the layout method. Currently only
  `"sugiyama"` is supported, which requires graphs with only directed
  edges.

## Value

A `data.frame` with columns `name`, `x`, and `y` containing node names
and their coordinates.

## See also

Other plotting:
[`caugi_plot()`](https://caugi.org/reference/caugi_plot.md),
[`plot()`](https://caugi.org/reference/plot.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)
layout <- caugi_layout(cg)
```
