# Create a caugi Graph Plot Object

Creates a grid graphics object (gTree) representing a `caugi` graph. If
the graph has not been built yet, it will be built automatically before
plotting. This implementation uses idiomatic grid graphics with
viewports for proper coordinate handling.

## Arguments

- x:

  A `caugi` object. Must contain only directed edges for Sugiyama
  layout.

- layout:

  Specifies the graph layout method. Can be:

  - A character string: `"auto"` (default), `"sugiyama"`,
    `"fruchterman-reingold"`, `"kamada-kawai"`, `"bipartite"`. See
    [`caugi_layout()`](https://caugi.org/reference/caugi_layout.md) for
    details.

  - A layout function: e.g., `caugi_layout_sugiyama`,
    `caugi_layout_bipartite`, etc. The function will be called with `x`
    and any additional arguments passed via `...`.

  - A pre-computed layout data.frame with columns `name`, `x`, and `y`.

- node_style:

  List of node styling parameters. Supports:

  - Appearance (passed to `gpar()`): `fill`, `col`, `lwd`, `lty`,
    `alpha`

  - Geometry: `padding` (text padding inside nodes in mm, default 2),
    `size` (node size multiplier, default 1)

- edge_style:

  List of edge styling parameters. Can specify global options or
  per-type options via `directed`, `undirected`, `bidirected`,
  `partial`. Supports:

  - Appearance (passed to `gpar()`): `col`, `lwd`, `lty`, `alpha`,
    `fill`.

  - Geometry: `arrow_size` (arrow length in mm, default 3)

- label_style:

  List of label styling parameters. Supports:

  - Appearance (passed to `gpar()`): `col`, `fontsize`, `fontface`,
    `fontfamily`, `cex`

- ...:

  Additional arguments (currently unused).

## Value

A `caugi_plot` object that wraps a `gTree` for grid graphics display.
The plot is automatically drawn when printed or explicitly plotted.

## See also

Other plotting:
[`caugi_layout()`](https://caugi.org/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/reference/caugi_layout_bipartite.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/reference/caugi_layout_sugiyama.md),
[`caugi_plot()`](https://caugi.org/reference/caugi_plot.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)

plot(cg)


# Use a specific layout method (as string)
plot(cg, layout = "kamada-kawai")


# Use a layout function
plot(cg, layout = caugi_layout_sugiyama)


# Pre-compute layout and use it
coords <- caugi_layout_fruchterman_reingold(cg)
plot(cg, layout = coords)


# Bipartite layout with a function
cg_bp <- caugi(A %-->% X, B %-->% X, C %-->% Y)
partition <- c(TRUE, TRUE, TRUE, FALSE, FALSE)
plot(cg_bp, layout = caugi_layout_bipartite, partition = partition)


# Customize nodes
plot(cg, node_style = list(fill = "lightgreen", padding = 0.8))


# Customize edges by type
plot(
  cg,
  edge_style = list(
    directed = list(col = "blue", arrow_size = 4),
    undirected = list(col = "red")
  )
)

```
