# Kamada-Kawai Stress Minimization Layout

Computes node coordinates using the Kamada-Kawai stress minimization
algorithm. High-quality force-directed layout that minimizes "stress" by
making Euclidean distances proportional to graph-theoretic distances.
Better preserves global structure and path lengths compared to
Fruchterman-Reingold. Ideal for publication-quality visualizations.
Works with all edge types and produces deterministic results.

## Usage

``` r
caugi_layout_kamada_kawai(x)
```

## Source

Kamada, T., & Kawai, S. (1989). An algorithm for drawing general
undirected graphs. Information Processing Letters, 31(1), 7-15.
[doi:10.1016/0020-0190(89)90102-6](https://doi.org/10.1016/0020-0190%2889%2990102-6)

## Arguments

- x:

  A `caugi` object.

## Value

A `data.frame` with columns `name`, `x`, and `y` containing node names
and their coordinates.

## See also

Other plotting:
[`caugi_layout()`](https://caugi.org/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/reference/caugi_layout_bipartite.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_sugiyama()`](https://caugi.org/reference/caugi_layout_sugiyama.md),
[`caugi_plot()`](https://caugi.org/reference/caugi_plot.md),
[`plot()`](https://caugi.org/reference/plot.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  B %<->% C,
  C %-->% D
)
layout <- caugi_layout_kamada_kawai(cg)
```
