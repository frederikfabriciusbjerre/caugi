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
[`plot()`](https://caugi.org/reference/plot.md)
