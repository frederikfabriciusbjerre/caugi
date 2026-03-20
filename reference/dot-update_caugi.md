# Update nodes and edges of a `caugi`

Internal helper to add or remove nodes/edges. Rust is the source of
truth - we get current state from Rust, modify it, and build a new
session.

## Usage

``` r
.update_caugi(
  cg,
  nodes = NULL,
  edges = NULL,
  action = c("add", "remove", "replace"),
  inplace = FALSE
)
```

## Arguments

- cg:

  A `caugi` object.

- nodes:

  A `data.frame` with column `name` for node names to add/remove.

- edges:

  A `data.frame` with columns `from`, `edge`, `to` for edges to
  add/remove.

- action:

  One of `"add"`, `"remove"`, or `"replace"`.

- inplace:

  DEPRECATED Ignored. Kept for backward compatibility.

## Value

The updated `caugi` object.
