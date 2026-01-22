# Export caugi Graph to GraphML Format

Converts a caugi graph to the GraphML XML format as a string. GraphML is
widely supported by graph analysis tools and libraries.

## Usage

``` r
to_graphml(x)
```

## Arguments

- x:

  A `caugi` object.

## Value

A `caugi_graphml` object containing the GraphML representation.

## Details

The GraphML export includes:

- Node IDs and labels

- Edge types stored as a custom `edge_type` attribute

- Graph class stored as a graph-level attribute

Edge types are encoded using the caugi DSL operators (e.g., "–\>",
"\<-\>"). This allows for perfect round-trip conversion back to caugi.

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
[`to_mermaid()`](https://caugi.org/dev/reference/to_mermaid.md),
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

# Get GraphML string
graphml <- to_graphml(cg)
cat(graphml@content)
#> <?xml version="1.0" encoding="UTF-8"?>
#> <graphml xmlns="http://graphml.graphdrawing.org/xmlns" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd">
#>   <key id="edge_type" for="edge" attr.name="edge_type" attr.type="string"/>
#>   <key id="graph_class" for="graph" attr.name="graph_class" attr.type="string"/>
#>   <graph id="G" edgedefault="directed">
#>     <data key="graph_class">DAG</data>
#>     <node id="A"/>
#>     <node id="B"/>
#>     <node id="C"/>
#>     <node id="D"/>
#>     <edge source="A" target="B">
#>       <data key="edge_type">--&gt;</data>
#>     </edge>
#>     <edge source="A" target="C">
#>       <data key="edge_type">--&gt;</data>
#>     </edge>
#>     <edge source="B" target="D">
#>       <data key="edge_type">--&gt;</data>
#>     </edge>
#>     <edge source="C" target="D">
#>       <data key="edge_type">--&gt;</data>
#>     </edge>
#>   </graph>
#> </graphml>

# Write to file
if (FALSE) { # \dontrun{
write_graphml(cg, "graph.graphml")
} # }
```
