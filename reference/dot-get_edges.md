# Build edges `data.table` from verb call.

Internal helper to build edges `data.table` from verb call.

## Usage

``` r
.get_edges(from, edge, to, calls)
```

## Arguments

- from:

  Character vector of source node names.

- edge:

  Character vector of edge types.

- to:

  Character vector of target node names.

- calls:

  List of calls from `...`.

## Value

A `data.table` with columns `from`, `edge`, and `to`.
