# Circle Layout

Computes node coordinates by placing nodes evenly along the perimeter of
a circle. The first node is placed at the top of the circle, and
subsequent nodes proceed counter-clockwise. Edge structure is ignored.
Works with all edge types and produces deterministic results.

## Usage

``` r
caugi_layout_circle(x, ...)
```

## Arguments

- x:

  A `caugi` object.

- ...:

  Ignored. For future extensibility.

## Value

A `data.frame` with columns `name`, `x`, and `y` containing node names
and their coordinates.

## See also

Other plotting:
[`add-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/add-caugi_plot-caugi_plot.md),
[`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/dev/reference/caugi_layout_bipartite.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/dev/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/dev/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/dev/reference/caugi_layout_sugiyama.md),
[`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md),
[`caugi_plot()`](https://caugi.org/dev/reference/caugi_plot.md),
[`divide-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/divide-caugi_plot-caugi_plot.md),
[`plot()`](https://caugi.org/dev/reference/plot.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  B %-->% C,
  C %-->% D,
  D %-->% A
)
layout <- caugi_layout_circle(cg)
```
