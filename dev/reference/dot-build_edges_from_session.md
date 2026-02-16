# Build edges data.table from session

Internal helper to build edges data.table from Rust session.

## Usage

``` r
.build_edges_from_session(session)
```

## Arguments

- session:

  A pointer to the GraphSession Rust object.

## Value

A `data.table` with columns `from`, `edge`, and `to`.
