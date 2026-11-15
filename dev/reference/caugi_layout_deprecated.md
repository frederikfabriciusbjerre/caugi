# Deprecated layout functions

These functions are deprecated and will be removed in caugi 2.0.0. Use
[`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md) with
the matching `method` instead, e.g.
`caugi_layout(cg, method = "sugiyama")` for `caugi_layout_sugiyama(cg)`.

## Usage

``` r
caugi_layout_sugiyama(x, packing_ratio = 1.618034, ...)

caugi_layout_fruchterman_reingold(x, packing_ratio = 1.618034, ...)

caugi_layout_kamada_kawai(x, packing_ratio = 1.618034, ...)

caugi_layout_bipartite(x, partition = NULL, orientation = c("columns", "rows"))

caugi_layout_tiered(x, tiers, orientation = c("columns", "rows"))

caugi_layout_circle(x, ...)
```

## Arguments

- x:

  A `caugi` object.

- packing_ratio, ...:

  See
  [`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md).

- partition, tiers, orientation:

  See the `...` argument of
  [`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md).

## Value

See [`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md).
