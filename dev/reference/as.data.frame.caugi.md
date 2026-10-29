# Convert a `caugi` to a data.frame

Returns the graph as a plain `data.frame` with columns `from`, `edge`
and `to`: one row per edge, then one row per isolated node with the node
in `from` and `NA` in `edge` and `to`.
[`caugi()`](https://caugi.org/dev/reference/caugi.md) reads such rows
back as isolated nodes, so `caugi(edges_df = as.data.frame(cg))` keeps
every node. Use [`edges()`](https://caugi.org/dev/reference/edges.md)
for the edges alone.

## Usage

``` r
# S3 method for class 'caugi'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `caugi` object.

- row.names, optional:

  Passed to
  [`base::as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- ...:

  Passed to
  [`base::as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

## Value

A `data.frame` with columns `from`, `edge` and `to`.

## See also

Other caugi methods:
[`caugi-equality`](https://caugi.org/dev/reference/caugi-equality.md),
[`length.caugi()`](https://caugi.org/dev/reference/length.caugi.md),
[`print.caugi()`](https://caugi.org/dev/reference/print.caugi.md),
[`summary.caugi()`](https://caugi.org/dev/reference/summary.caugi.md)

## Examples

``` r
cg <- caugi(A %-->% B + C, B %---% C, D, class = "PDAG")
df <- as.data.frame(cg) # D has a row with edge = NA
caugi(edges_df = df, class = "PDAG") == cg # TRUE
#> [1] TRUE
```
