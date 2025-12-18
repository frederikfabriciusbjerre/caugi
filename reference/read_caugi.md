# Read caugi Graph from File

Reads a caugi graph from a file in the native caugi JSON format.

## Usage

``` r
read_caugi(path, lazy = FALSE)
```

## Arguments

- path:

  Character string specifying the file path.

- lazy:

  Logical; if `FALSE` (default), the graph is built immediately. If
  `TRUE`, graph building is deferred until needed.

## Value

A `caugi` object.

## Details

The function validates the file format and version, ensuring
compatibility with the current version of the caugi package.

## See also

Other export:
[`caugi_deserialize()`](https://caugi.org/reference/caugi_deserialize.md),
[`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/reference/caugi_export.md),
[`caugi_mermaid()`](https://caugi.org/reference/caugi_mermaid.md),
[`caugi_serialize()`](https://caugi.org/reference/caugi_serialize.md),
[`export-classes`](https://caugi.org/reference/export-classes.md),
[`format-caugi`](https://caugi.org/reference/format-caugi.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`format-mermaid`](https://caugi.org/reference/format-mermaid.md),
[`knit_print.caugi_export`](https://caugi.org/reference/knit_print.caugi_export.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md),
[`to_mermaid()`](https://caugi.org/reference/to_mermaid.md),
[`write_caugi()`](https://caugi.org/reference/write_caugi.md),
[`write_dot()`](https://caugi.org/reference/write_dot.md),
[`write_mermaid()`](https://caugi.org/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  class = "DAG"
)

# Write and read
tmp <- tempfile(fileext = ".caugi.json")
write_caugi(cg, tmp)
cg2 <- read_caugi(tmp)

# Clean up
unlink(tmp)
```
