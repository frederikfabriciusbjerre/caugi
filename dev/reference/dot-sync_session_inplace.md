# Update an existing session in place

Internal helper to mutate an existing GraphSession pointer with updated
nodes and edges.

## Usage

``` r
.sync_session_inplace(session, node_names, edges_dt, simple, class)
```

## Arguments

- session:

  A GraphSession external pointer.

- node_names:

  Character vector of node names.

- edges_dt:

  A data.table with columns `from`, `edge`, `to`.

- simple:

  Logical; whether the graph is simple.

- class:

  Character; target graph class or `"AUTO"`.

## Value

A list with `session` and resolved `class`.
