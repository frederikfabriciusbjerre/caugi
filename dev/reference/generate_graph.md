# Generate a `caugi` using Erdős-Rényi.

Sample a random DAG or CPDAG using Erdős-Rényi for random graph
generation.

## Usage

``` r
generate_graph(n, m = NULL, p = NULL, class = c("DAG", "CPDAG"))
```

## Arguments

- n:

  Integer \>= 0. Number of nodes in the graph.

- m:

  Integer in `0, n*(n-1)/2`. Number of edges in the graph. Exactly one
  of `m` or `p` must be supplied.

- p:

  Numeric in `[0,1]`. Probability of edge creation. Exactly one of `m`
  or `p` must be supplied.

- class:

  "DAG" or "CPDAG".

## Value

The sampled `caugi` object.

## See also

Other simulation functions:
[`simulate_data()`](https://caugi.org/dev/reference/simulate_data.md)

## Examples

``` r
# generate a random DAG with 5 nodes and 4 edges
dag <- generate_graph(n = 5, m = 4, class = "DAG")

# generate a random CPDAG with 5 nodes and edge probability 0.3
cpdag <- generate_graph(n = 5, p = 0.3, class = "CPDAG")
```
