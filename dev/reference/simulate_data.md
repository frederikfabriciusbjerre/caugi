# Simulate data from a `caugi` DAG.

Simulate data from a `caugi` object of class DAG using a linear
structural equation model (SEM). As standard, the data is simulated from
a DAG, where each node is generated as a linear combination of its
parents plus Gaussian noise, following the topological order of the
graph. Nodes without custom equations are simulated using auto-generated
linear Gaussian relationships.

## Usage

``` r
simulate_data(
  cg,
  n,
  ...,
  standardize = TRUE,
  coef_range = c(0.1, 0.9),
  error_sd = 1,
  seed = NULL
)
```

## Arguments

- cg:

  A `caugi` object of class DAG.

- n:

  Integer; number of observations to simulate.

- ...:

  Named expressions for custom structural equations. Names must match
  node names in the graph. Expressions can reference parent node names
  and the variable `n` (sample size). Nodes without custom equations use
  auto-generated linear Gaussian relationships.

- standardize:

  Logical; if `TRUE`, standardize all variables to have mean 0 and
  standard deviation 1. Default is `TRUE`.

- coef_range:

  Numeric vector of length 2; range for random edge coefficients that
  will be sampled uniformly. Default is `c(0.1, 0.9)`.

- error_sd:

  Numeric; standard deviation for error terms in auto-generated
  equations. Default is `1`.

- seed:

  Optional integer; random seed for reproducibility.

## Value

A `data.frame` with `n` rows and one column per node, ordered according
to the node order in the graph.

## See also

Other simulation functions:
[`generate_graph()`](https://caugi.org/dev/reference/generate_graph.md)

## Examples

``` r
cg <- caugi(A %-->% B, B %-->% C, A %-->% C, class = "DAG")

# Fully automatic simulation
df <- simulate_data(cg, n = 100)

# With standardization
df <- simulate_data(cg, n = 100, standardize = TRUE)

# Custom equations for some nodes
df <- simulate_data(cg, n = 100,
  A = rnorm(n, mean = 10, sd = 2),
  B = 0.5 * A + rnorm(n, sd = 0.5)
)

# Reproducible simulation
df <- simulate_data(cg, n = 100, seed = 42)
```
