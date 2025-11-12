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

## Examples

``` r
cg <- caugi(A %-->% C, B %-->% C, class = "DAG")
moralize(cg) # A -- B, A -- C, B -- C
#>      name
#>    <char>
#> 1:      A
#> 2:      B
#> 3:      C
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    ---      B
#> 2:      A    ---      C
#> 3:      B    ---      C
```
