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

Other export: [`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/reference/caugi_export.md),
[`export-classes`](https://caugi.org/reference/export-classes.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`knit_print.caugi_export`](https://caugi.org/reference/knit_print.caugi_export.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md)

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
