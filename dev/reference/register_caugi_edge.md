# Register a new edge type in the global registry.

Register a new edge type in the global registry.

## Usage

``` r
register_caugi_edge(glyph, tail_mark, head_mark, class, symmetric = FALSE)
```

## Arguments

- glyph:

  A string representing the edge glyph (e.g., `"-->"`, `"<->"`). It must
  not contain `%` or whitespace.

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

## Details

Exporters such as
[`to_dot()`](https://caugi.org/dev/reference/to_dot.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md) and
[`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md) refuse
graphs with a custom glyph, as they can't record what it means.

## See also

Other registry:
[`registry`](https://caugi.org/dev/reference/registry.md)

## Examples

``` r
# first, for reproducability, we reset the registry to default
reset_caugi_registry()

# create a new registry
reg <- caugi_registry()

# register an edge: causalDisco writes forbidden edges in background
# knowledge as `!-->`
register_caugi_edge(
  glyph = "!-->",
  tail_mark = "tail",
  head_mark = "arrow",
  class = "directed",
  symmetric = FALSE
)

# now, this edge is available for caugi graphs:
cg <- caugi(A %-->% B, B %!-->% C, class = "UNKNOWN")

# reset the registry to default
reset_caugi_registry()
```
