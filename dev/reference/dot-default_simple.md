# Default `simple` flag for a graph class

Only `"UNKNOWN"` and `"ADMG"` allow multiple edges between a pair of
nodes by default; every other class is simple. `"AUTO"` builds
permissively and takes the default of the class it resolves to.

## Usage

``` r
.default_simple(class)
```

## Arguments

- class:

  Character; a graph class.

## Value

A logical scalar.
