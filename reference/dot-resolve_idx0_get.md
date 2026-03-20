# Resolve node name or index to 0-based index.

Internal helper function to resolve either a node name or a node index
to a 0-based index using the Rust session. `.resolve_idx0_get` expects a
single value, while `.resolve_idx0_mget` can return multiple values.

## Usage

``` r
.resolve_idx0_get(session, node_name = NULL, node_index = NULL)

.resolve_idx0_mget(session, node_name = NULL, node_index = NULL)
```

## Arguments

- session:

  A GraphSession pointer.

- node_name:

  Optional character vector of node names.

- node_index:

  Optional numeric vector of 1-based node indices.
