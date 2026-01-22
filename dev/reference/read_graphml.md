# Read GraphML File to caugi Graph

Imports a GraphML file as a caugi graph. Supports GraphML files exported
from caugi with full edge type information.

## Usage

``` r
read_graphml(path, class = NULL)
```

## Arguments

- path:

  File path to the GraphML file.

- class:

  Graph class to assign. If `NULL` (default), attempts to read from the
  GraphML metadata. If not present, defaults to "UNKNOWN".

## Value

A `caugi` object.

## Details

This function provides basic GraphML import support. It reads:

- Nodes and their IDs

- Edges with source and target

- Edge types (if present in `edge_type` attribute)

- Graph class (if present in graph data)

For GraphML files not created by caugi, edge types default to "–\>" for
directed graphs and "—" for undirected graphs.

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
[`to_dot()`](https://caugi.org/dev/reference/to_dot.md),
[`to_graphml()`](https://caugi.org/dev/reference/to_graphml.md),
[`to_mermaid()`](https://caugi.org/dev/reference/to_mermaid.md),
[`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md),
[`write_dot()`](https://caugi.org/dev/reference/write_dot.md),
[`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/dev/reference/write_mermaid.md)

## Examples

``` r
# Create and export a graph
cg <- caugi(
  A %-->% B,
  B %-->% C,
  class = "DAG"
)

tmp <- tempfile(fileext = ".graphml")
write_graphml(cg, tmp)

# Read it back
cg2 <- read_graphml(tmp)

# Clean up
unlink(tmp)
```
