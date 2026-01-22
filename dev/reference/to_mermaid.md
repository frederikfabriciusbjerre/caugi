# Export caugi Graph to Mermaid Format

Converts a caugi graph to the Mermaid flowchart format as a string.
Mermaid diagrams can be rendered in Quarto, R Markdown, GitHub, and many
other platforms.

## Usage

``` r
to_mermaid(x, direction = "TD")
```

## Arguments

- x:

  A `caugi` object.

- direction:

  Graph direction: "TB" (top-bottom), "TD" (top-down), "BT"
  (bottom-top), "LR" (left-right), or "RL" (right-left). Default is
  "TD".

## Value

A `caugi_mermaid` object containing the Mermaid representation.

## Details

The function handles different edge types:

- Directed edges (`-->`) use `-->` in Mermaid

- Undirected edges (`---`) use `---` in Mermaid

- Bidirected edges (`<->`) use `<-->` in Mermaid

- Partial edges (`o->`) use `o-->` in Mermaid (circle end)

Node names are automatically escaped if they contain special characters.

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
[`write_caugi()`](https://caugi.org/dev/reference/write_caugi.md),
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

# Get Mermaid string
mmd <- to_mermaid(cg)
mmd@content
#> [1] "flowchart TD\n  A --> B\n  A --> C\n  B --> D\n  C --> D"

# With custom direction
mmd <- to_mermaid(cg, direction = "LR")
```
