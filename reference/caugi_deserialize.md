# Deserialize caugi Graph from JSON String

Converts a JSON string in the native caugi format back to a caugi graph.
This is a lower-level function; consider using
[`read_caugi()`](https://caugi.org/reference/read_caugi.md) for reading
from files.

## Usage

``` r
caugi_deserialize(json, lazy = FALSE)
```

## Arguments

- json:

  Character string containing the JSON representation.

- lazy:

  Logical; if `FALSE` (default), the graph is built immediately. If
  `TRUE`, graph building is deferred until needed.

## Value

A `caugi` object.

## See also

Other export: [`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
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
[`write_dot()`](https://caugi.org/reference/write_dot.md),
[`write_graphml()`](https://caugi.org/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
json <- caugi_serialize(cg)
cg2 <- caugi_deserialize(json)
```
