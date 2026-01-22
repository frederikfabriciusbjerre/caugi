# Serialize caugi Graph to JSON String

Converts a caugi graph to a JSON string in the native caugi format. This
is a lower-level function; consider using
[`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md) for
writing to files.

## Usage

``` r
caugi_serialize(x, comment = NULL, tags = NULL)
```

## Arguments

- x:

  A `caugi` object or an object coercible to `caugi`.

- comment:

  Optional character string with a comment about the graph.

- tags:

  Optional character vector of tags for categorizing the graph.

## Value

A character string containing the JSON representation.

## See also

Other export:
[`caugi_deserialize()`](https://caugi.org/dev/reference/caugi_deserialize.md),
[`caugi_dot()`](https://caugi.org/dev/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/dev/reference/caugi_export.md),
[`caugi_graphml()`](https://caugi.org/dev/reference/caugi_graphml.md),
[`caugi_mermaid()`](https://caugi.org/dev/reference/caugi_mermaid.md),
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
[`write_graphml()`](https://caugi.org/dev/reference/write_graphml.md),
[`write_mermaid()`](https://caugi.org/dev/reference/write_mermaid.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
json <- caugi_serialize(cg)
cat(json)
#> {
#>   "$schema": "https://caugi.org/schemas/caugi-v1.schema.json",
#>   "format": "caugi",
#>   "version": "1.0.0",
#>   "graph": {
#>     "class": "DAG",
#>     "nodes": [
#>       "A",
#>       "B"
#>     ],
#>     "edges": [
#>       {
#>         "from": "A",
#>         "to": "B",
#>         "edge": "-->"
#>       }
#>     ]
#>   }
#> }
```
