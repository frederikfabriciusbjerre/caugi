# Compare caugi objects for equality

S3 method for `all.equal` that compares caugi objects by their graph
content (nodes, edges, simple, class) rather than session identity. This
is used by testthat edition 2.

## Usage

``` r
# S3 method for class '`equal.caugi::caugi`'
all(target, current, ...)
```

## Arguments

- target:

  A `caugi` object.

- current:

  A `caugi` object.

- ...:

  Additional arguments (ignored).

## Value

`TRUE` if equal, or a character vector describing differences.
