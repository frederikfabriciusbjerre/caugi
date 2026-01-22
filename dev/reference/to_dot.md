# Export caugi Graph to DOT Format

Converts a caugi graph to the Graphviz DOT format as a string. The DOT
format can be used with Graphviz tools for visualization and analysis.

## Usage

``` r
to_dot(x, graph_attrs = list(), node_attrs = list(), edge_attrs = list())
```

## Arguments

- x:

  A `caugi` object.

- graph_attrs:

  Named list of graph attributes (e.g., `list(rankdir = "LR")`).

- node_attrs:

  Named list of default node attributes.

- edge_attrs:

  Named list of default edge attributes.

## Value

A `caugi_dot` object containing the DOT representation.

## Details

The function handles different edge types:

- Directed edges (`-->`) use `->` in DOT

- Undirected edges (`---`) use `--` in DOT (or `->` with `dir=none` in
  digraphs)

- Bidirected edges (`<->`) use `->` with `[dir=both]` attribute

- Partial edges (`o->`) use `->` with `[arrowtail=odot, dir=both]`
  attribute

## See also

Other export:
[`caugi_deserialize()`](https://caugi.org/dev/reference/caugi_deserialize.md),
[`caugi_dot()`](https://caugi.org/dev/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/dev/reference/caugi_export.md),
[`caugi_graphml()`](https://caugi.org/dev/reference/caugi_graphml.md),
[`caugi_mermaid()`](https://caugi.org/dev/reference/caugi_mermaid.md),
[`caugi_serialize()`](https://caugi.org/dev/reference/caugi_serialize.md),
[`export-classes`](https://caugi.org/dev/reference/export-classes.md),
[`format-caugi`](https://caugi.org/dev/reference/format-caugi.md),
[`format-dot`](https://caugi.org/dev/reference/format-dot.md),
[`format-graphml`](https://caugi.org/dev/reference/format-graphml.md),
[`format-mermaid`](https://caugi.org/dev/reference/format-mermaid.md),
[`knit_print.caugi_export`](https://caugi.org/dev/reference/knit_print.caugi_export.md),
[`read_caugi()`](https://caugi.org/dev/reference/read_caugi.md),
[`read_graphml()`](https://caugi.org/dev/reference/read_graphml.md),
[`to_graphml()`](https://caugi.org/dev/reference/to_graphml.md),
[`to_mermaid()`](https://caugi.org/dev/reference/to_mermaid.md),
[`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md),
[`write_dot()`](https://caugi.org/dev/reference/write_dot.md),
[`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/dev/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)

# Get DOT string
dot <- to_dot(cg)
dot@content
#> [1] "digraph {\n\n  // Nodes\n  A;\n  B;\n  C;\n  D;\n\n  // Edges\n  A -> B;\n  A -> C;\n  B -> D;\n  C -> D;\n}"

# With custom attributes
dot <- to_dot(
  cg,
  graph_attrs = list(rankdir = "LR"),
  node_attrs = list(shape = "box")
)
```
