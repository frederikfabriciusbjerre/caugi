# Convert a graph pointer to a `caugi` S7 object

Convert a graph pointer from Rust to a `caugi` to a S7 object.

## Usage

``` r
.view_to_caugi(ptr, node_names = NULL)
```

## Arguments

- ptr:

  A pointer to the underlying Rust graph structure.

- node_names:

  Optional character vector of node names. If `NULL` (default), nodes
  will be named `V1`, `V2`, ..., `Vn`.

## Value

A `caugi` object representing the graph.
