# Convert node names to 0-based indices

Convert node names to 0-based indices using the Rust session's name
lookup.

## Usage

``` r
.nodes_to_indices(cg, nodes)
```

## Arguments

- cg:

  A `caugi` object.

- nodes:

  A character vector of node names.

## Value

An integer vector of 0-based indices.
