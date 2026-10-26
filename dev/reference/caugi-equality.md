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

## Details

Row order is ignored, and an edge whose glyph is symmetric in the
graph's own edge registry is compared as an unordered pair, so `A --- B`
and `B --- A` are the same edge. Edges are also compared by their full
definition, so a glyph re-registered with a different meaning does not
match the original. Asymmetric glyphs are direction-sensitive, so
`A --> B` and `B --> A` are not.

## See also

Other caugi methods:
[`length.caugi()`](https://caugi.org/dev/reference/length.caugi.md),
[`print.caugi()`](https://caugi.org/dev/reference/print.caugi.md)

## Examples

``` r
cg1 <- caugi(A %-->% B, class = "DAG")
cg2 <- caugi(A %-->% B, class = "DAG")
cg1 == cg2 # TRUE
#> [1] TRUE
cg1 != caugi(A %-->% C, class = "DAG") # TRUE
#> [1] TRUE

# Symmetric edges are unordered, so these are the same graph.
caugi(A %---% B, class = "UG") == caugi(B %---% A, class = "UG") # TRUE
#> [1] TRUE

# Directed edges are not.
caugi(A %-->% B, class = "DAG") == caugi(B %-->% A, class = "DAG") # FALSE
#> [1] FALSE
```
