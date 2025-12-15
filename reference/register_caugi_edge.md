# Register a new edge type in the global registry.

Register a new edge type in the global registry.

## Usage

``` r
register_caugi_edge(glyph, tail_mark, head_mark, class, symmetric = FALSE)
```

## Arguments

- glyph:

  A string representing the edge glyph (e.g., `"-->"`, `"<->"`).

- tail_mark:

  One of "arrow", "tail", "circle", "other".

- head_mark:

  One of "arrow", "tail", "circle", "other".

- class:

  One of "directed","undirected","bidirected","partial".

- symmetric:

  Logical.

## Value

TRUE, invisibly.

## See also

Other registry:
[`registry`](https://frederikfabriciusbjerre.github.io/caugi/reference/registry.md)

## Examples

``` r
# first, for reproducability, we reset the registry to default
reset_caugi_registry()

# create a new registry
reg <- caugi_registry()

# register an edge
register_caugi_edge(
  glyph = "<--",
  tail_mark = "arrow",
  head_mark = "tail",
  class = "directed",
  symmetric = FALSE
)

# now, this edge is available for caugi graphs:
cg <- caugi(A %-->% B, B %<--% C, class = "DAG")

# reset the registry to default
reset_caugi_registry()
```
