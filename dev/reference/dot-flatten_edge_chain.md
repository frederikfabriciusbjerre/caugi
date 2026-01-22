# Flatten a chained edge expression

Given a chained edge expression, flatten it into its terms and
operators.

## Usage

``` r
.flatten_edge_chain(call_expr)
```

## Arguments

- call_expr:

  A call expression representing a chained edge.

## Value

A list with two elements, `terms` and `ops`.
