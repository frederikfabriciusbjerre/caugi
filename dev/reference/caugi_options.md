# Get or set global options for caugi

Configure global defaults for caugi, including plot composition spacing
and default visual styles for nodes, edges, labels, and titles.

## Usage

``` r
caugi_options(...)
```

## Arguments

- ...:

  Named values to update options with, or unnamed option names to
  retrieve. To query all options, call without arguments.

## Value

When setting, returns (invisibly) the previous values for the updated
options. When getting (no arguments or unnamed character vector),
returns the requested options.

## Details

Currently supported options are nested under the `plot` key:

- `spacing`: A [`grid::unit()`](https://rdrr.io/r/grid/unit.html)
  controlling space between composed plots (default:
  `grid::unit(1, "lines")`)

- `node_style`: List of default node appearance parameters:

  - `fill`: Fill color (default: `"lightgrey"`)

  - `padding`: Padding around labels in mm (default: `2`)

  - `size`: Size multiplier (default: `1`)

- `edge_style`: List of default edge appearance parameters:

  - `arrow_size`: Arrow size in mm (default: `3`)

  - `circle_size`: Radius of endpoint circles for partial edges in mm
    (default: `1.5`)

  - `fill`: Arrow/line color (default: `"black"`)

- `label_style`: List of label text parameters (see
  [`grid::gpar()`](https://rdrr.io/r/grid/gpar.html))

- `title_style`: List of title text parameters:

  - `col`: Text color (default: `"black"`)

  - `fontface`: Font face (default: `"bold"`)

  - `fontsize`: Font size in pts (default: `14.4`)

Options set via `caugi_options()` serve as global defaults that can be
overridden by arguments to
[`plot()`](https://caugi.org/dev/reference/plot.md).

## See also

[`plot()`](https://caugi.org/dev/reference/plot.md) for per-plot style
arguments, [`grid::gpar()`](https://rdrr.io/r/grid/gpar.html) for
available graphical parameters

## Examples

``` r
# Query all options
caugi_options()
#> $plot
#> $plot$spacing
#> [1] 1lines
#> 
#> $plot$node_style
#> $plot$node_style$fill
#> [1] "lightgrey"
#> 
#> $plot$node_style$padding
#> [1] 2
#> 
#> $plot$node_style$size
#> [1] 1
#> 
#> 
#> $plot$edge_style
#> $plot$edge_style$arrow_size
#> [1] 3
#> 
#> $plot$edge_style$circle_size
#> [1] 1.5
#> 
#> $plot$edge_style$fill
#> [1] "black"
#> 
#> 
#> $plot$label_style
#> list()
#> 
#> $plot$title_style
#> $plot$title_style$col
#> [1] "black"
#> 
#> $plot$title_style$fontface
#> [1] "bold"
#> 
#> $plot$title_style$fontsize
#> [1] 14.4
#> 
#> 
#> $plot$tier_style
#> $plot$tier_style$boxes
#> [1] TRUE
#> 
#> $plot$tier_style$labels
#> [1] TRUE
#> 
#> $plot$tier_style$fill
#> [1] "lightsteelblue"
#> 
#> $plot$tier_style$col
#> [1] "transparent"
#> 
#> $plot$tier_style$label_style
#> list()
#> 
#> $plot$tier_style$lwd
#> [1] 1
#> 
#> $plot$tier_style$alpha
#> [1] 1
#> 
#> $plot$tier_style$padding
#> [1] 4mm
#> 
#> 
#> 

# Query specific option
caugi_options("plot")
#> $plot
#> $plot$spacing
#> [1] 1lines
#> 
#> $plot$node_style
#> $plot$node_style$fill
#> [1] "lightgrey"
#> 
#> $plot$node_style$padding
#> [1] 2
#> 
#> $plot$node_style$size
#> [1] 1
#> 
#> 
#> $plot$edge_style
#> $plot$edge_style$arrow_size
#> [1] 3
#> 
#> $plot$edge_style$circle_size
#> [1] 1.5
#> 
#> $plot$edge_style$fill
#> [1] "black"
#> 
#> 
#> $plot$label_style
#> list()
#> 
#> $plot$title_style
#> $plot$title_style$col
#> [1] "black"
#> 
#> $plot$title_style$fontface
#> [1] "bold"
#> 
#> $plot$title_style$fontsize
#> [1] 14.4
#> 
#> 
#> $plot$tier_style
#> $plot$tier_style$boxes
#> [1] TRUE
#> 
#> $plot$tier_style$labels
#> [1] TRUE
#> 
#> $plot$tier_style$fill
#> [1] "lightsteelblue"
#> 
#> $plot$tier_style$col
#> [1] "transparent"
#> 
#> $plot$tier_style$label_style
#> list()
#> 
#> $plot$tier_style$lwd
#> [1] 1
#> 
#> $plot$tier_style$alpha
#> [1] 1
#> 
#> $plot$tier_style$padding
#> [1] 4mm
#> 
#> 
#> 

# Set plot spacing
caugi_options(plot = list(spacing = grid::unit(2, "lines")))

# Set default node style
caugi_options(plot = list(
  node_style = list(fill = "lightblue", padding = 3)
))

# Set multiple options at once
caugi_options(plot = list(
  spacing = grid::unit(1.5, "lines"),
  node_style = list(fill = "lightblue", padding = 3),
  edge_style = list(arrow_size = 4, fill = "darkgray"),
  title_style = list(col = "blue", fontsize = 16)
))

# Reset to defaults
caugi_options(caugi_default_options())
```
