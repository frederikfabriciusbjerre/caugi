# Summarize a `caugi`

Summarizes a graph by its class, size and the number of edges of each
type.

## Usage

``` r
# S3 method for class 'caugi'
summary(object, ...)

# S3 method for class 'caugi_summary'
print(x, ...)
```

## Arguments

- object:

  A `caugi` object.

- ...:

  Not used.

- x:

  A `caugi_summary` object.

## Value

[`summary()`](https://rdrr.io/r/base/summary.html) returns a
`caugi_summary` object: a list with `graph_class`, `n_nodes`, `n_edges`
and `edge_types` (a table of edge counts by glyph).
[`print()`](https://caugi.org/dev/reference/print.caugi.md) returns its
input invisibly.

## See also

Other caugi methods:
[`as.data.frame.caugi()`](https://caugi.org/dev/reference/as.data.frame.caugi.md),
[`caugi-equality`](https://caugi.org/dev/reference/caugi-equality.md),
[`length.caugi()`](https://caugi.org/dev/reference/length.caugi.md),
[`print.caugi()`](https://caugi.org/dev/reference/print.caugi.md)

## Examples

``` r
cg <- caugi(A %-->% B + C, B %---% C, class = "PDAG")
summary(cg)
#> <caugi PDAG: 3 nodes, 3 edges>
#>   ---  1
#>   -->  2
```
