# Update nodes and edges of a `caugi`

Internal helper to add or remove nodes/edges and mark graph as not
built.

## Usage

``` r
.update_caugi(
  cg,
  nodes = NULL,
  edges = NULL,
  action = c("add", "remove"),
  inplace = FALSE
)
```

## Arguments

- cg:

  A `caugi` object.

- nodes:

  A tibble with column `name` for node names to add/remove.

- edges:

  A tibble with columns `from`, `edge`, `to` for edges to add/remove.

- action:

  One of `"add"` or `"remove"`.

- inplace:

  Logical, whether to modify the graph inplace or not.

## Value

The updated `caugi` object.
