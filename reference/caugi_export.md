# S7 Base Class for Caugi Exports

A base class for all caugi export formats. Provides common structure and
behavior for different export formats (DOT, GraphML, etc.).

## Usage

``` r
caugi_export(content = character(0), format = character(0))
```

## Arguments

- content:

  A character string containing the exported graph.

- format:

  A character string indicating the export format.

## See also

Other export:
[`caugi_deserialize()`](https://caugi.org/reference/caugi_deserialize.md),
[`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
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
[`write_dot()`](https://caugi.org/reference/write_dot.md),
[`write_graphml()`](https://caugi.org/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/reference/write_mermaid.md)
