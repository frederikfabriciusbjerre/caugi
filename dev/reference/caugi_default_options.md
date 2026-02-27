# Default options for caugi

Returns the default options for the caugi package. Useful for resetting
options to their original state.

## Usage

``` r
caugi_default_options()
```

## Value

A list of default options for caugi.

## See also

[`caugi_options()`](https://caugi.org/dev/reference/caugi_options.md)
for setting and getting options

## Examples

``` r
# Get defaults
caugi_default_options()
#> $use_open_graph_definition
#> [1] TRUE
#> 
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

# Reset to defaults
caugi_options(caugi_default_options())
```
