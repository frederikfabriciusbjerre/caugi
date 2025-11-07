# Infix operators for edge specifications

These operators are used to specify edges in
[`caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi.md).
Should be used internally in
[`caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi.md)
calls.

## Usage

``` r
lhs %-->% rhs
```

## Arguments

- lhs:

  The left-hand side node expression.

- rhs:

  The right-hand side node expression.

## Value

A tibble with columns `from`, `to`, and `edge`.
