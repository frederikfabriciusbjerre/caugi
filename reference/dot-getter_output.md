# Output object of getter queries

Helper to format the output of getter queries.

## Usage

``` r
.getter_output(cg, idx0, nodes)
```

## Arguments

- cg:

  A `caugi` object.

- idx0:

  A vector of zero-based node indices.

- nodes:

  A vector of node names.

## Value

A list of character vectors, each a set of node names. If only one node
is requested, returns a character vector.
