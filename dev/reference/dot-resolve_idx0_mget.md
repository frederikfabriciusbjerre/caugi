# Resolve node names or indices to 0-based indices.

Internal helpers that resolve node names, or 1-based node indices, to
0-based indices using the Rust session. `.resolve_idx0_xy` also requires
at least one node.

## Usage

``` r
.resolve_idx0_xy(session, node_name, node_index, arg)

.resolve_idx0_mget(session, node_name = NULL, node_index = NULL)
```

## Arguments

- session:

  A GraphSession pointer.

- node_name:

  Optional character vector of node names.

- node_index:

  Optional numeric vector of 1-based node indices.
