# Proxy for waldo comparison of caugi objects

Provides a proxy representation for waldo comparison that compares graph
content (nodes, edges, simple, class) rather than session identity.

## Usage

``` r
`compare_proxy.caugi::caugi`(x, path)
```

## Arguments

- x:

  A `caugi` object.

- path:

  The path to the object (for error messages).

## Value

A list with `object` (proxy) and `path`.
