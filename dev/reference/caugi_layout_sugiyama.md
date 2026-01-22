# Sugiyama Hierarchical Layout

Computes node coordinates using the Sugiyama hierarchical layout
algorithm. Optimized for directed acyclic graphs (DAGs), placing nodes
in layers to emphasize hierarchical structure and causal flow from top
to bottom.

## Usage

``` r
caugi_layout_sugiyama(x, packing_ratio = 1.618034, ...)
```

## Source

Sugiyama, K., Tagawa, S., & Toda, M. (1981). Methods for visual
understanding of hierarchical system structures. IEEE Transactions on
Systems, Man, and Cybernetics, 11(2), 109-125.
[doi:10.1109/TSMC.1981.4308636](https://doi.org/10.1109/TSMC.1981.4308636)

## Arguments

- x:

  A `caugi` object. Must contain only directed edges.

- packing_ratio:

  Aspect ratio for packing disconnected components (width/height).
  Default is the golden ratio (1.618) which works well with widescreen
  displays. Use `1.0` for square grid, `2.0` for wider layouts, `0.5`
  for taller layouts, `Inf` for single row, or `0.0` for single column.

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
[`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md),
[`caugi_plot()`](https://caugi.org/dev/reference/caugi_plot.md),
[`divide-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/divide-caugi_plot-caugi_plot.md),
[`plot()`](https://caugi.org/dev/reference/plot.md)

## Examples

``` r
cg <- caugi(A %-->% B + C, B %-->% D, C %-->% D, class = "DAG")
layout <- caugi_layout_sugiyama(cg)
```
