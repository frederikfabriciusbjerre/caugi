# S7 Class for caugi Plot

An S7 object that wraps a grid gTree for displaying caugi graphs.
Similar to ggplot objects, these are created by the plot method but not
drawn until explicitly printed or plotted. This allows for returning
plot objects from functions and controlling when/where they are
displayed.

## Usage

``` r
caugi_plot(grob = NULL)
```

## Arguments

- grob:

  A grid gTree representing the graph plot.

## Value

A `caugi_plot` S7 object wrapping the supplied `grob`.

## See also

Other plotting:
[`add-caugi_plot-caugi_plot`](https://caugi.org/reference/add-caugi_plot-caugi_plot.md),
[`caugi_layout()`](https://caugi.org/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/reference/caugi_layout_bipartite.md),
[`caugi_layout_circle()`](https://caugi.org/reference/caugi_layout_circle.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/reference/caugi_layout_sugiyama.md),
[`caugi_layout_tiered()`](https://caugi.org/reference/caugi_layout_tiered.md),
[`divide-caugi_plot-caugi_plot`](https://caugi.org/reference/divide-caugi_plot-caugi_plot.md),
[`plot.caugi()`](https://caugi.org/reference/plot.caugi.md)
