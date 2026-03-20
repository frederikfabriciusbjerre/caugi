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
[`condition_marginalize()`](https://caugi.org/reference/condition_marginalize.md),
[`dag_from_pdag()`](https://caugi.org/reference/dag_from_pdag.md),
[`exogenize()`](https://caugi.org/reference/exogenize.md),
[`latent_project()`](https://caugi.org/reference/latent_project.md),
[`meek_closure()`](https://caugi.org/reference/meek_closure.md),
[`mutate_caugi()`](https://caugi.org/reference/mutate_caugi.md),
[`normalize_latent_structure()`](https://caugi.org/reference/normalize_latent_structure.md),
[`skeleton()`](https://caugi.org/reference/skeleton.md)

## Examples

``` r
cg <- caugi(A %-->% C, B %-->% C, class = "DAG")
moralize(cg) # A -- B, A -- C, B -- C
#> <caugi object; 3 nodes, 3 edges; simple: TRUE; session=0x561906aa75f0>
#>   graph_class: UG
#>   nodes: A, B, C
#>   edges: A---B, A---C, B---C
```
