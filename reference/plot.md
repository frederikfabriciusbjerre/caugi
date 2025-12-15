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

  Character string specifying the layout method. Options: \* `"auto"`:
  Automatically choose sugiyama for graphs with only directed edges,
  otherwise fruchterman-reingold (default) \* `"sugiyama"`: Hierarchical
  layout for DAGs (requires only directed edges) \*
  `"fruchterman-reingold"`: Fruchterman-Reingold spring-electrical
  layout (fast, works with all edge types). \* `"kamada-kawai"`:
  Kamada-Kawai stress minimization (high quality, better distance
  preservation, works with all edge types). See
  [`caugi_layout()`](https://caugi.org/reference/caugi_layout.md) for
  more details on these algorithms.

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
