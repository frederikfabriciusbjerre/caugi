# Write caugi Graph to GraphML File

Exports a caugi graph to a GraphML file.

## Usage

``` r
write_graphml(x, path)
```

## Arguments

- x:

  A `caugi` object.

- path:

  File path for the output GraphML file.

## Value

Invisibly returns `NULL`. Called for side effects.

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
[`write_dot()`](https://caugi.org/reference/write_dot.md),
[`write_mermaid()`](https://caugi.org/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(A %-->% B + C, class = "DAG")

tmp <- tempfile(fileext = ".graphml")
write_graphml(cg, tmp)

# Read it back
cg2 <- read_graphml(tmp)

# Clean up
unlink(tmp)
```
