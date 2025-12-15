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
  [`to_mermaid()`](https://caugi.org/reference/to_mermaid.md), such as
  `direction`.

## Value

Invisibly returns the path to the file.

## See also

Other export: [`caugi_dot()`](https://caugi.org/reference/caugi_dot.md),
[`caugi_export()`](https://caugi.org/reference/caugi_export.md),
[`caugi_mermaid()`](https://caugi.org/reference/caugi_mermaid.md),
[`export-classes`](https://caugi.org/reference/export-classes.md),
[`format-dot`](https://caugi.org/reference/format-dot.md),
[`format-mermaid`](https://caugi.org/reference/format-mermaid.md),
[`knit_print.caugi_export`](https://caugi.org/reference/knit_print.caugi_export.md),
[`to_dot()`](https://caugi.org/reference/to_dot.md),
[`to_mermaid()`](https://caugi.org/reference/to_mermaid.md),
[`write_dot()`](https://caugi.org/reference/write_dot.md)

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
