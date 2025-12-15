# Moralize a DAG

Moralizing a DAG involves connecting all parents of each node and then
converting all directed edges into undirected edges.

## Usage

``` r
moralize(cg)
```

## Arguments

- cg:

  A `caugi` object (DAG).

## Value

A `caugi` object representing the moralized graph (UG).

## Details

This changes the graph from a Directed Acyclic Graph (DAG) to an
Undirected Graph (UG), also known as a Markov Graph.

## See also

Other operations:
[`mutate_caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/mutate_caugi.md),
[`skeleton()`](https://frederikfabriciusbjerre.github.io/caugi/reference/skeleton.md)

## Examples

``` r
cg <- caugi(A %-->% C, B %-->% C, class = "DAG")
moralize(cg) # A -- B, A -- C, B -- C
#> <caugi object; 3 nodes, 3 edges; simple: TRUE; built: TRUE; ptr=0x55d07eb68ac0>
#>   graph_class: UG
#>   nodes: A, B, C
#>   edges: A---B, A---C, B---C
```
