# Export Format Classes

S7 classes for representing caugi graphs in various export formats.
These classes provide a common interface for serializing graphs to
different text formats like DOT, GraphML, JSON, etc.

## Base Class

[`caugi_export`](https://caugi.org/dev/reference/caugi_export.md) is the
base class for all export formats. It provides:

- `content` property: Character string containing the serialized graph

- `format` property: Character string indicating the format type

- Common methods: [`print()`](https://caugi.org/dev/reference/print.md),
  [`as.character()`](https://rdrr.io/r/base/character.html),
  `knit_print()`

## Subclasses

- [`caugi_dot`](https://caugi.org/dev/reference/caugi_dot.md): DOT
  format for Graphviz visualization

- [`caugi_mermaid`](https://caugi.org/dev/reference/caugi_mermaid.md):
  Mermaid format for web-based visualization

## See also

Other export:
[`caugi_deserialize()`](https://caugi.org/dev/reference/caugi_deserialize.md),
[`caugi_dot()`](https://caugi.org/dev/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/dev/reference/caugi_export.md),
[`caugi_graphml()`](https://caugi.org/dev/reference/caugi_graphml.md),
[`caugi_mermaid()`](https://caugi.org/dev/reference/caugi_mermaid.md),
[`caugi_serialize()`](https://caugi.org/dev/reference/caugi_serialize.md),
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
[`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/dev/reference/write_mermaid.md)
