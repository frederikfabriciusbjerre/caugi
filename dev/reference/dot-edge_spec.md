# Edge specification infix operators

These infix operators are used to specify edges in
[`caugi()`](https://caugi.org/dev/reference/caugi.md). This function
helps build infix operators.

## Usage

``` r
.edge_spec(from_sym, to_expr, glyph)
```

## Arguments

- from_sym:

  A symbol representing the source node.

- to_expr:

  An expression representing the target node(s). Can be a symbol,
  string, number, `c(...)`, or a combination using `+`.

- glyph:

  A string representing the edge glyph (e.g., `"-->"`, `"<->"`).

## Value

A `data.table` with columns `from`, `to`, and `edge`.
