# Equality operators for caugi objects

S3 methods for `==` and `!=` that compare two caugi objects by their
graph content (nodes, edges, simple, class) rather than session
identity. Returns `FALSE` (resp. `TRUE`) when the other operand is not a
caugi object.

## Usage

``` r
# S3 method for class '`caugi::caugi`'
e1 == e2

# S3 method for class '`caugi::caugi`'
e1 != e2
```

## Arguments

- e1, e2:

  A `caugi` object (one or both sides).

## Value

A single logical.

## See also

Other caugi methods:
[`length.caugi()`](https://caugi.org/reference/length.caugi.md),
[`print.caugi()`](https://caugi.org/reference/print.caugi.md)

## Examples

``` r
cg1 <- caugi(A %-->% B, class = "DAG")
cg2 <- caugi(A %-->% B, class = "DAG")
cg1 == cg2 # TRUE
#> [1] TRUE
cg1 != caugi(A %-->% C, class = "DAG") # TRUE
#> [1] TRUE
```
