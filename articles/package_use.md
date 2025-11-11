# How to use caugi in a package

``` r
library(caugi)
set.seed(42)
```

Now, let’s see how you can use `caugi` in your own R package. We will
work through an example to illustrate how you could approach this.

## The setup

Imagine that you want to build a causal discovery function that utilizes
`caugi` for graph representation and manipulation. While seemingly not a
very good idea, let’s pretend your algorithmic idea is to measure the
correlation between variables and then draw causal conclusions based on
this[¹](#fn1).

``` r
#' @title Correlation implies causation!
#'
#' @param df A `data.frame` with numeric columns
#'
#' @returns A `caugi` representing the causal graph that is totally true!
correlation_implies_causation <- function(df) {
  NULL # not developed yet!
}
```

Let’s assume we have a named data frame:

``` r
# create correlated data using MASS
df <- MASS::mvrnorm(
  n = 100,
  mu = c(0, 0, 0),
  Sigma = matrix(c(
    1, 0.8, 0.3,
    0.8, 1, 0.4,
    0.3, 0.4, 1
  ), nrow = 3)
) |> as.data.frame()
head(df)
#>           V1         V2          V3
#> 1 -2.2248040 -0.8720414  0.00560844
#> 2  0.2526361  0.2097850  1.18506791
#> 3  0.3619044 -0.5104396 -0.95743426
#> 4 -0.5733562 -1.6093245  1.16043547
#> 5 -0.5471823  0.1960346 -0.83809176
#> 6 -0.2835526  0.4438799  0.09421533
```

## We know the nodes!

Now, we *know* that the `caugi` should include all variables in the
`df`. We don’t know if the graph is a `DAG`, `PDAG`, or something else,
so we will create a graph of the `UNKNOWN` class. We can begin with
that, as a start:

``` r
#' @title Correlation implies causation!
#'
#' @param df A `data.frame` with numeric columns
#'
#' @returns A `caugi` representing the causal graph that is totally true!
correlation_implies_causation <- function(df) {
  cg <- caugi::caugi(nodes = names(df))
  return(NULL)
}
```

## Adding edges based on correlation

We can now compute the correlation matrix and add edges based on some
arbitrary threshold:

``` r
#' @title Correlation implies causation!
#'
#' @param df A `data.frame` with numeric columns
#'
#' @returns A `caugi` representing the causal graph that is totally true!
correlation_implies_causation <- function(df) {
  cg <- caugi::caugi(nodes = names(df))
  cor_matrix <- cor(df)
  # Add edges for correlations above 0.5
  for (i in seq_len(ncol(cor_matrix))) {
    for (j in 1:i) {
      if (i != j && abs(cor_matrix[i, j]) > 0.5) {
        from <- names(df)[j]
        to <- names(df)[i]
        cg <- caugi::add_edges(cg, from = from, edge = "-->", to = to) # add edge to caugi
      }
    }
  }
  return(cg)
}
```

Now, when you call `correlation_implies_causation(df)`, it will return a
`caugi` graph with edges based on the correlation threshold.

## Trying it out

Let’s try it out!

``` r
cg <- correlation_implies_causation(df)
cg
#>      name
#>    <char>
#> 1:     V1
#> 2:     V2
#> 3:     V3
#>      from   edge     to
#>    <char> <char> <char>
#> 1:     V1    -->     V2
```

## Something is up!

Let’s inspect the object:

``` r
cg@built
#> [1] FALSE
```

We can see that the object is not built yet. So, we have to include that
as well. Building is important in `caugi`, as it finalizes the graph
structure and prepares it for analysis. It also makes sure that the
graph class agrees with the input graph.

``` r
#' @title Correlation implies causation!
#'
#' @param df A `data.frame` with numeric columns
#'
#' @returns A `caugi` representing the causal graph that is totally true!
correlation_implies_causation <- function(df) {
  cg <- caugi::caugi(nodes = names(df))
  cor_matrix <- cor(df)
  # Add edges for correlations above 0.5
  for (i in seq_len(ncol(cor_matrix))) {
    for (j in 1:i) {
      if (i != j && abs(cor_matrix[i, j]) > 0.5) {
        from <- names(df)[j]
        to <- names(df)[i]
        cg <- caugi::add_edges(cg, from = from, edge = "-->", to = to) # add edge to caugi
      }
    }
  }
  caugi::build(cg)
  return(cg)
}
```

**Hold on, it doesn’t check every iteration?** No, `caugi` is designed
to be efficient, so it only checks the graph’s validity when you
explicitly call
[`build()`](https://frederikfabriciusbjerre.github.io/caugi/reference/build.md).
This allows you to add multiple edges without incurring the overhead of
validation after each addition. You *can* ensure that your algorithm
breaks, when introducing a faulty edge by building at each step. This is
computationally expensive, but sometimes necessary for debugging.

## Class of the output

Now, you might want to specify the class of the output graph. Let’s say
that *if possible* the output should be a DAG (which is advantageous for
several reasons), but you don’t want to enforce acyclicity in the
algorithm, as that could sometimes cause your function to throw an
error. You would rather have it return a graph in any case, but if it
*is* a DAG, then we return a DAG.

This is not ideal in `caugi`. Because of the way `caugi` works, this is
a bit slower, but we can still do it!

``` r
#' @title Correlation implies causation!
#'
#' @param df A `data.frame` with numeric columns
#'
#' @returns A `caugi` representing the causal graph that is totally true!
correlation_implies_causation <- function(df) {
  cg <- caugi::caugi(nodes = names(df))
  cor_matrix <- cor(df)
  # Add edges for correlations above 0.5
  cg <- caugi::caugi(nodes = names(df))
  cor_matrix <- cor(df)
  # Add edges for correlations above 0.5
  for (i in seq_len(ncol(cor_matrix))) {
    for (j in 1:i) {
      if (i != j && abs(cor_matrix[i, j]) > 0.5) {
        from <- names(df)[j]
        to <- names(df)[i]
        cg <- caugi::add_edges(cg, from = from, edge = "-->", to = to) # add edge to caugi
      }
    }
  }
  it_is <- is_dag(cg) # this builds, since it is a query
  if (it_is) {
    cg <- caugi::caugi(
      from = caugi::edges(cg)$from,
      edge = caugi::edges(cg)$edge,
      to = caugi::edges(cg)$to,
      nodes = caugi::nodes(cg)$name,
      class = "DAG"
    )
  }
  return(cg)
}
```

Now, when you call `correlation_implies_causation(df)`, it will return a
`caugi` graph that is a DAG if possible, otherwise an `"UNKNOWN"` graph.

``` r
cg <- correlation_implies_causation(df)
cg
#>      name
#>    <char>
#> 1:     V1
#> 2:     V2
#> 3:     V3
#>      from   edge     to
#>    <char> <char> <char>
#> 1:     V1    -->     V2
cg@graph_class
#> [1] "DAG"
```

## That’s it!

You have now successfully integrated `caugi` into your own R package
function! Good luck and happy coding!

------------------------------------------------------------------------

1.  Note that correlation does not imply causation!
