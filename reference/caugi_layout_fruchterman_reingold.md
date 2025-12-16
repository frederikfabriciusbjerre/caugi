# Fruchterman-Reingold Force-Directed Layout

Computes node coordinates using the Fruchterman-Reingold force-directed
layout algorithm. Fast spring-electrical model that treats edges as
springs and nodes as electrically charged particles. Produces organic,
symmetric layouts with uniform edge lengths. Works with all edge types
and produces deterministic results.

## Usage

``` r
caugi_layout_fruchterman_reingold(x)
```

## Source

Fruchterman, T. M. J., & Reingold, E. M. (1991). Graph drawing by
force-directed placement. Software: Practice and Experience, 21(11),
1129-1164.
[doi:10.1002/spe.4380211102](https://doi.org/10.1002/spe.4380211102)

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
[`caugi_layout_kamada_kawai()`](https://caugi.org/reference/caugi_layout_kamada_kawai.md),
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
layout <- caugi_layout_fruchterman_reingold(cg)
```
