# Compose Plots Horizontally

Arrange two plots side-by-side with configurable spacing. The `+` and
`|` operators are equivalent and can be used interchangeably.
Compositions can be nested to create complex multi-plot layouts.

## Arguments

- e1:

  A `caugi_plot` object (left plot)

- e2:

  A `caugi_plot` object (right plot)

## Value

A `caugi_plot` object containing the composed layout

## Details

The spacing between plots is controlled by the global option
`caugi_options()$plot$spacing`, which defaults to
`grid::unit(1, "lines")`. Compositions can be nested arbitrarily:

- `p1 + p2` - two plots side-by-side

- `(p1 + p2) + p3` - three plots in a row

- `(p1 + p2) / p3` - two plots on top, one below

## See also

[`caugi_options()`](https://caugi.org/dev/reference/caugi_options.md)
for configuring spacing and default styles

Other plotting:
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
cg1 <- caugi(A %-->% B, B %-->% C)
cg2 <- caugi(X %-->% Y, Y %-->% Z)

p1 <- plot(cg1, main = "Graph 1")
p2 <- plot(cg2, main = "Graph 2")

# Horizontal composition
p1 + p2

p1 | p2 # equivalent


# Adjust spacing
caugi_options(plot = list(spacing = grid::unit(2, "lines")))
p1 + p2

```
