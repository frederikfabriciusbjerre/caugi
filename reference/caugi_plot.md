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

## See also

Other plotting:
[`caugi_layout()`](https://caugi.org/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/reference/caugi_layout_bipartite.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/reference/caugi_layout_sugiyama.md),
[`plot()`](https://caugi.org/reference/plot.md)
