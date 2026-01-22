# Compose Plots Vertically

Stack two plots vertically with configurable spacing. Compositions can
be nested to create complex multi-plot layouts.

## Arguments

- e1:

  A `caugi_plot` object (top plot)

- e2:

  A `caugi_plot` object (bottom plot)

## Value

A `caugi_plot` object containing the composed layout

## Details

The spacing between plots is controlled by the global option
`caugi_options()$plot$spacing`, which defaults to
`grid::unit(1, "lines")`. Compositions can be nested arbitrarily:

- `p1 / p2` - two plots stacked vertically

- `p1 / p2 / p3` - three plots in a column

- `(p1 + p2) / p3` - two plots on top, one below

## See also

[`caugi_options()`](https://caugi.org/dev/reference/caugi_options.md)
for configuring spacing and default styles

Other plotting:
[`add-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/add-caugi_plot-caugi_plot.md),
[`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/dev/reference/caugi_layout_bipartite.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/dev/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/dev/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/dev/reference/caugi_layout_sugiyama.md),
[`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md),
[`caugi_plot()`](https://caugi.org/dev/reference/caugi_plot.md),
[`plot()`](https://caugi.org/dev/reference/plot.md)

## Examples

``` r
cg1 <- caugi(A %-->% B, B %-->% C)
cg2 <- caugi(X %-->% Y, Y %-->% Z)

p1 <- plot(cg1, main = "Graph 1")
p2 <- plot(cg2, main = "Graph 2")

# Vertical composition
p1 / p2


# Mixed composition
(p1 + p2) / p1

```
