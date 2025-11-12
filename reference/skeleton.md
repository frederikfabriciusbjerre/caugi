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

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
skeleton(cg) # A --- B
#>      name
#>    <char>
#> 1:      A
#> 2:      B
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    ---      B
```
