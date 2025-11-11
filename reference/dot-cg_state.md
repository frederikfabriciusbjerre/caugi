# Create the state environment for a `caugi` (internal)

Internal function to create the state environment for a `caugi`. This
function is not intended to be used directly by users.

## Usage

``` r
.cg_state(
  nodes,
  edges,
  ptr,
  built,
  simple,
  class,
  name_index_map,
  index_name_map
)
```

## Arguments

- nodes:

  A `data.table` of nodes with a `name` column.

- edges:

  A `data.table` of edges with `from`, `edge`, and `to` columns.

- ptr:

  A pointer to the underlying Rust graph structure (or `NULL` if not
  built).

- built:

  Logical; whether the graph has been built.

- simple:

  Logical; whether the graph is simple (no parallel edges or
  self-loops).

- class:

  Character; one of `"UNKNOWN"`, `"DAG"`, or `"PDAG"`.

- name_index_map:

  A `fastmap` mapping node names to their zero indexed indices.

## Value

An environment containing the graph state.
