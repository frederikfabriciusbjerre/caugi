# Write caugi Graph to File

Writes a caugi graph to a file in the native caugi JSON format. This
format is designed for reproducibility, caching, and sharing caugi
graphs across R sessions.

## Usage

``` r
write_caugi(x, path, comment = NULL, tags = NULL)
```

## Arguments

- x:

  A `caugi` object or an object coercible to `caugi`.

- path:

  Character string specifying the file path.

- comment:

  Optional character string with a comment about the graph.

- tags:

  Optional character vector of tags for categorizing the graph.

## Value

Invisibly returns the input `x`.

## Details

The caugi format is a versioned JSON schema that captures:

- Graph structure (nodes and edges with their types)

- Graph class (DAG, PDAG, ADMG, UG, etc.)

- Optional metadata (comments and tags)

Edge types are encoded using their DSL operators (e.g., `"-->"`,
`"<->"`, `"--"`).

For a complete guide to the format, see
[`vignette("serialization", package = "caugi")`](https://caugi.org/dev/articles/serialization.md).
The formal JSON Schema is available at:
<https://caugi.org/schemas/caugi-v1.schema.json>

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
[`write_dot()`](https://caugi.org/dev/reference/write_dot.md),
[`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/dev/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  C %-->% D,
  class = "DAG"
)

# Write to file
tmp <- tempfile(fileext = ".caugi.json")
write_caugi(cg, tmp, comment = "Example DAG")

# Read back
cg2 <- read_caugi(tmp)
identical(edges(cg), edges(cg2))
#> [1] TRUE

# Clean up
unlink(tmp)
```
