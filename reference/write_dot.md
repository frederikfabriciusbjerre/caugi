# Write caugi Graph to DOT File

Writes a caugi graph to a file in Graphviz DOT format.

## Usage

``` r
write_dot(x, file, ...)
```

## Arguments

- x:

  A `caugi` object.

- file:

  Path to output file.

- ...:

  Additional arguments passed to
  [`to_dot()`](https://caugi.org/reference/to_dot.md), such as
  `graph_attrs`, `node_attrs`, and `edge_attrs`.

## Value

Invisibly returns the path to the file.

## See also

Other export:
[`caugi_deserialize()`](https://caugi.org/reference/caugi_deserialize.md),
[`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/reference/caugi_export.md),
[`caugi_graphml()`](https://caugi.org/reference/caugi_graphml.md),
[`caugi_mermaid()`](https://caugi.org/reference/caugi_mermaid.md),
[`caugi_serialize()`](https://caugi.org/reference/caugi_serialize.md),
[`export-classes`](https://caugi.org/reference/export-classes.md),
[`format-caugi`](https://caugi.org/reference/format-caugi.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`format-graphml`](https://caugi.org/reference/format-graphml.md),
[`format-mermaid`](https://caugi.org/reference/format-mermaid.md),
[`knit_print.caugi_export`](https://caugi.org/reference/knit_print.caugi_export.md),
[`read_caugi()`](https://caugi.org/reference/read_caugi.md),
[`read_graphml()`](https://caugi.org/reference/read_graphml.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md),
[`to_graphml()`](https://caugi.org/reference/to_graphml.md),
[`to_mermaid()`](https://caugi.org/reference/to_mermaid.md),
[`write_caugi()`](https://caugi.org/reference/write_caugi.md),
[`write_graphml()`](https://caugi.org/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)

if (FALSE) { # \dontrun{
# Write to file
write_dot(cg, "graph.dot")

# With custom attributes
write_dot(
  cg,
  "graph.dot",
  graph_attrs = list(rankdir = "LR")
)
} # }
```
