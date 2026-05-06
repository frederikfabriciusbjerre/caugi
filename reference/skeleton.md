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
[`condition_marginalize()`](https://caugi.org/reference/condition_marginalize.md),
[`dag_from_pdag()`](https://caugi.org/reference/dag_from_pdag.md),
[`exogenize()`](https://caugi.org/reference/exogenize.md),
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/reference/meek_closure.md),
[`moralize()`](https://caugi.org/reference/moralize.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/reference/normalize_latent_structure.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
skeleton(cg) # A --- B
#> <caugi object; 2 nodes, 1 edges; simple: TRUE; session=0x55ce6e027dd0>
#>   graph_class: UG
#>   nodes: A, B
#>   edges: A---B
```
