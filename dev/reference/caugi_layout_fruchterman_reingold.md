# Fruchterman-Reingold Force-Directed Layout

Computes node coordinates using the Fruchterman-Reingold force-directed
layout algorithm. Fast spring-electrical model that treats edges as
springs and nodes as electrically charged particles. Produces organic,
symmetric layouts with uniform edge lengths. Works with all edge types
and produces deterministic results.

## Usage

``` r
caugi_layout_fruchterman_reingold(x, packing_ratio = 1.618034, ...)
```

## Source

Fruchterman, T. M. J., & Reingold, E. M. (1991). Graph drawing by
force-directed placement. Software: Practice and Experience, 21(11),
1129-1164.
[doi:10.1002/spe.4380211102](https://doi.org/10.1002/spe.4380211102)

## Arguments

- x:

  A `caugi` object.

- packing_ratio:

  Aspect ratio for packing disconnected components (width/height).
  Default is the golden ratio (1.618) which works well with widescreen
  displays. Use `1.0` for square grid, `2.0` for wider layouts, `0.5`
  for taller layouts, `Inf` for single row, or `0.0` for single column.

- ...:

  Ignored. For future extensibility.

## Value

A `data.frame` with columns `name`, `x`, and `y` containing node names
and their coordinates.

## See also

Other plotting:
[`add-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/add-caugi_plot-caugi_plot.md),
[`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md),
[`caugi_layout_bipartite()`](https://caugi.org/dev/reference/caugi_layout_bipartite.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/dev/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/dev/reference/caugi_layout_sugiyama.md),
[`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md),
[`caugi_plot()`](https://caugi.org/dev/reference/caugi_plot.md),
[`divide-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/divide-caugi_plot-caugi_plot.md),
[`plot()`](https://caugi.org/dev/reference/plot.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  B %<->% C,
  C %-->% D
)
layout <- caugi_layout_fruchterman_reingold(cg)
```
