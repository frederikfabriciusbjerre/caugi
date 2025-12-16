# Print a `caugi`

Print a `caugi`

## Arguments

- x:

  A `caugi` object.

- max_nodes:

  Optional numeric; maximum number of node names to consider. If `NULL`,
  the method automatically prints as many as fit on one console line
  (plus a separate truncation line if needed).

- max_edges:

  Optional numeric; maximum number of edges to consider. If `NULL`, the
  method automatically prints as many edges as fit on two console lines
  (plus a separate truncation line if needed).

- ...:

  Not used.

## Value

The input `caugi` object, invisibly.

## See also

Other caugi methods: [`length()`](https://caugi.org/reference/length.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
print(cg)
#> <caugi object; 2 nodes, 1 edges; simple: TRUE; built: TRUE; ptr=0x559d07dc5e70>
#>   graph_class: DAG
#>   nodes: A, B
#>   edges: A-->B
```
