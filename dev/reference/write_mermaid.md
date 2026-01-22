# Write caugi Graph to Mermaid File

Writes a caugi graph to a file in Mermaid format.

## Usage

``` r
write_mermaid(x, file, ...)
```

## Arguments

- x:

  A `caugi` object.

- file:

  Path to output file.

- ...:

  Additional arguments passed to
  [`to_mermaid()`](https://caugi.org/dev/reference/to_mermaid.md), such
  as `direction`.

## Value

Invisibly returns the path to the file.

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
[`to_dot()`](https://caugi.org/dev/reference/to_dot.md),
[`to_graphml()`](https://caugi.org/dev/reference/to_graphml.md),
[`to_mermaid()`](https://caugi.org/dev/reference/to_mermaid.md),
[`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md),
[`write_dot()`](https://caugi.org/dev/reference/write_dot.md),
[`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md)

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
write_mermaid(cg, "graph.mmd")

# With custom direction
write_mermaid(cg, "graph.mmd", direction = "LR")
} # }
```
