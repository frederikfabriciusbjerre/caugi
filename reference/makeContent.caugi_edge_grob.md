# Make Content for Custom Edge Grob

This S3 method for grid::makeContent handles dynamic edge endpoint
calculation at draw time. It converts edge direction to absolute
coordinates (mm) to properly handle aspect ratio, then applies node
radius offsets before converting back to native coordinates.

## Usage

``` r
# S3 method for class 'caugi_edge_grob'
makeContent(x)
```

## Arguments

- x:

  A caugi_edge_grob object

## Value

The modified grob with children set to the adjusted line
