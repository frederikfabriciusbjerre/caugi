# Exogenize a graph

Exogenize a graph by removing all ingoing edges to the set of nodes
specified (i.e., make the nodes exogenous), as well as joining the
parents of the nodes specified to the children of the nodes specified.

## Usage

``` r
exogenize(cg, nodes)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"`.

- nodes:

  A character vector of node names to exogenize. Must be a subset of the
  nodes in the graph.

## Value

A `caugi` object representing the exogenized graph.

## See also

Other operations:
[`condition_marginalize()`](https://caugi.org/dev/reference/condition_marginalize.md),
[`latent_project()`](https://caugi.org/dev/reference/latent_project.md),
[`moralize()`](https://caugi.org/dev/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/dev/reference/mutate_caugi.md),
[`skeleton()`](https://caugi.org/dev/reference/skeleton.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
exogenize(cg, nodes = "B") # A, B
#> <caugi object; 2 nodes, 0 edges; simple: TRUE; built: FALSE; ptr=0x55d2dc9225c0>
#>   graph_class: DAG
#>   nodes: A, B
#>   edges: (none)
```
