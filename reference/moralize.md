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
[`skeleton()`](https://frederikfabriciusbjerre.github.io/caugi/reference/skeleton.md)
