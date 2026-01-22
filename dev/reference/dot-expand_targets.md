# Helper to expand the right-hand side of an edge specification

This function expands the right-hand side of an edge specification into
a character vector of target node names. It handles various forms of
input, including symbols, calls with `+`, calls with
[`c()`](https://rdrr.io/r/base/c.html), and character literals.

## Usage

``` r
.expand_targets(expr)
```

## Arguments

- expr:

  An expression representing the target node(s).

## Value

A character vector of target node names.
