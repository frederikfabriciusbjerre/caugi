# Node membership in a `caugi`

`"A" %in% cg` tests whether the graph has a node named `A`, and
`match("A", cg)` gives its position in `nodes(cg)`.

## Usage

``` r
# S3 method for class '`caugi::caugi`'
mtfrm(x)
```

## Arguments

- x:

  A `caugi` object.

## Value

The node names, which [`match()`](https://rdrr.io/r/base/match.html) and
`%in%` compare against.

## See also

Other caugi methods:
[`as.data.frame.caugi()`](https://caugi.org/dev/reference/as.data.frame.caugi.md),
[`caugi-equality`](https://caugi.org/dev/reference/caugi-equality.md),
[`length.caugi()`](https://caugi.org/dev/reference/length.caugi.md),
[`print.caugi()`](https://caugi.org/dev/reference/print.caugi.md),
[`summary.caugi()`](https://caugi.org/dev/reference/summary.caugi.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
"A" %in% cg # TRUE
#> [1] TRUE
c("B", "Z") %in% cg # TRUE FALSE
#> [1]  TRUE FALSE
match("B", cg) # 2
#> [1] 2
```
