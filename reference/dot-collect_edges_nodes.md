# Collect edges and nodes

Collect edges (via .parse_edge_arg) and explicitly declared nodes (no
edges).

## Usage

``` r
.collect_edges_nodes(calls)
```

## Arguments

- calls:

  A list of expressions from caugi(...)

## Value

A list with two elements:

- edges: a `data.table` with columns `from`, `edge`, `to`

- declared: a character vector of explicitly declared nodes
