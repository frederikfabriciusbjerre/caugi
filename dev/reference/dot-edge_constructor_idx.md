# Edge constructor using indices.

Internal function to construct edges for `caugi` objects using indices.

## Usage

``` r
.edge_constructor_idx(from_idx, edge, to_idx, node_names)
```

## Arguments

- from_idx:

  Integer vector of source node indices.

- edge:

  Character vector of edge glyphs.

- to_idx:

  Integer vector of target node indices.

- node_names:

  Character vector of node names.

## Value

A `data.table` object with columns `from`, `edge`, and `to`.
