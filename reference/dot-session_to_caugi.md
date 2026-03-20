# Convert a graph session to a `caugi` S7 object

Convert a graph pointer from Rust to a `caugi` to a S7 object.

## Usage

``` r
.session_to_caugi(session, node_names = NULL)
```

## Arguments

- session:

  A pointer to the underlying Rust GraphSession.

- node_names:

  Optional character vector of node names. If `NULL` (default), node
  names will be taken from the session.

## Value

A `caugi` object representing the graph.
