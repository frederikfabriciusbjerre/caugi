# Exogenize a graph

Exogenize a graph by removing all ingoing edges to the set of nodes
specified.

## Usage

``` r
exogenize(cg, nodes)
```

## Arguments

- cg:

  A `caugi` object.

- nodes:

  A character vector of node names to exogenize. Must be a subset of the
  nodes in the graph.

## Value

A `caugi` object representing the exogenized graph.

## Details

This function removes all ingoing edges to the set of nodes specified.

## See also

Other operations:
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`skeleton()`](https://caugi.org/reference/skeleton.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
exogenize(cg, nodes = "B") # A, B
#> <caugi object; 2 nodes, 0 edges; simple: TRUE; built: FALSE; ptr=0x55b979dc79e0>
#>   graph_class: DAG
#>   nodes: A, B
#>   edges: (none)
```
