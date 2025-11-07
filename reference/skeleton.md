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
[`moralize()`](https://frederikfabriciusbjerre.github.io/caugi/reference/moralize.md)
