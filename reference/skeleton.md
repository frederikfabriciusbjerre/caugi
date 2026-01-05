# Get the skeleton of a graph

The skeleton of a graph is obtained by replacing all directed edges with
undirected edges.

## Usage

``` r
skeleton(cg)
```

## Arguments

- cg:

  A `caugi` object. Either a DAG or PDAG.

## Value

A `caugi` object representing the skeleton of the graph (UG).

## Details

This changes the graph from any class to an Undirected Graph (UG), also
known as a Markov Graph.

## See also

Other operations:
[`exogenize()`](https://caugi.org/reference/exogenize.md),
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
skeleton(cg) # A --- B
#> <caugi object; 2 nodes, 1 edges; simple: TRUE; built: TRUE; ptr=0x5611cdd53410>
#>   graph_class: UG
#>   nodes: A, B
#>   edges: A---B
```
