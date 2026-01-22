# Bipartite Graph Layout

Computes node coordinates for bipartite graphs, placing nodes in two
parallel lines (rows or columns) based on a partition. If the graph has
not been built yet, it will be built automatically before computing the
layout.

## Usage

``` r
caugi_layout_bipartite(x, partition = NULL, orientation = c("columns", "rows"))
```

## Arguments

- x:

  A `caugi` object.

- partition:

  Optional logical vector indicating node partitions. Nodes with `TRUE`
  are placed in one partition and nodes with `FALSE` in the other.
  Length must equal the number of nodes. Both partitions must be
  non-empty. If `NULL` (default), attempts to detect bipartite structure
  automatically by assigning nodes without incoming edges to one
  partition and others to the second partition.

- orientation:

  Character string specifying the layout orientation:

  - `"columns"`: Two vertical columns. First partition on right (x=1),
    second partition on left (x=0).

  - `"rows"`: Two horizontal rows. First partition on top (y=1), second
    partition on bottom (y=0).

## Value

A `data.frame` with columns `name`, `x`, and `y` containing node names
and their coordinates.

## See also

Other plotting:
[`add-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/add-caugi_plot-caugi_plot.md),
[`caugi_layout()`](https://caugi.org/dev/reference/caugi_layout.md),
[`caugi_layout_fruchterman_reingold()`](https://caugi.org/dev/reference/caugi_layout_fruchterman_reingold.md),
[`caugi_layout_kamada_kawai()`](https://caugi.org/dev/reference/caugi_layout_kamada_kawai.md),
[`caugi_layout_sugiyama()`](https://caugi.org/dev/reference/caugi_layout_sugiyama.md),
[`caugi_layout_tiered()`](https://caugi.org/dev/reference/caugi_layout_tiered.md),
[`caugi_plot()`](https://caugi.org/dev/reference/caugi_plot.md),
[`divide-caugi_plot-caugi_plot`](https://caugi.org/dev/reference/divide-caugi_plot-caugi_plot.md),
[`plot()`](https://caugi.org/dev/reference/plot.md)

## Examples

``` r
# Create a bipartite graph (causes -> effects)
cg <- caugi(A %-->% X, A %-->% Y, B %-->% X, B %-->% Y)
partition <- c(TRUE, TRUE, FALSE, FALSE) # A, B = causes, X, Y = effects

# Two horizontal rows (causes on top)
layout_rows <- caugi_layout_bipartite(cg, partition, orientation = "rows")

# Two vertical columns (causes on right)
layout_cols <- caugi_layout_bipartite(cg, partition, orientation = "columns")
```
