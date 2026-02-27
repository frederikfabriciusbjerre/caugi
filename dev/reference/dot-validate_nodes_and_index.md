# Validate nodes or index argument

Validate that either `nodes` or `index` is supplied (but not both) and
that they are of the correct type (non-NA character vector for `nodes`,
non-NA numeric vector for `index`).

## Usage

``` r
.validate_nodes_and_index(nodes = NULL, index = NULL)
```

## Arguments

- nodes:

  A character vector of node names. If supplied, must be non-NA
  character vector.

- index:

  A numeric vector of node indices. If supplied, must be non-NA numeric
  vector.

## Value

A list with `nodes_supplied` and `index_supplied` logical values.
