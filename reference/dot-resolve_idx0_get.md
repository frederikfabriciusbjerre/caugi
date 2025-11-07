# Resolve node name or index to 0-based index.

Internal helper function to resolve either a node name or a node index
to a 0-based index. `.resolve_idx0_get` uses `get` on the `fastmap` and
expects a single value, while `.resolve_idx0_mget` uses `mget` and can
return multiple values.

## Usage

``` r
.resolve_idx0_get(nm_idx_map, node_name = NULL, node_index = NULL)

.resolve_idx0_mget(nm_idx_map, node_name = NULL, node_index = NULL)
```

## Arguments

- nm_idx_map:

  A `fastmap` mapping node names to 0-based indices from a `caugi`.

- node_name:

  Optional character vector of node names.

- node_index:

  Optional numeric vector of 1-based node indices.

## See also

[fastmap::fastmap](https://r-lib.github.io/fastmap/reference/fastmap.html)
