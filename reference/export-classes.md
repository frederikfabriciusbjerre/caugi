# Export Format Classes

S7 classes for representing caugi graphs in various export formats.
These classes provide a common interface for serializing graphs to
different text formats like DOT, GraphML, JSON, etc.

## Base Class

[`caugi_export`](https://caugi.org/reference/caugi_export.md) is the
base class for all export formats. It provides:

- `content` property: Character string containing the serialized graph

- `format` property: Character string indicating the format type

- Common methods: [`print()`](https://caugi.org/reference/print.md),
  [`as.character()`](https://rdrr.io/r/base/character.html),
  `knit_print()`

## Subclasses

- [`caugi_dot`](https://caugi.org/reference/caugi_dot.md): DOT format
  for Graphviz visualization

## See also

Other export: [`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/reference/caugi_export.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`knit_print.caugi_export`](https://caugi.org/reference/knit_print.caugi_export.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md),
[`write_dot()`](https://caugi.org/reference/write_dot.md)
