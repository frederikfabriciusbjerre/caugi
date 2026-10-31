# Convert a caugi to an adjacency matrix

With `coding = "binary"` (the default), only supports the edge types
found in a PDAG (`-->` and `---`). A `---` edge is written as `1` in
both directions, so other symmetric edges such as `<->` are rejected
rather than encoded the same way.

With `coding = "marks"`, writes `pcalg`'s `amat.pag` coding, which
covers `-->`, `<->`, `---`, `o->`, `--o` and `o-o`: `0` no edge, `1`
circle, `2` arrowhead, `3` tail, where `m[i, j]` is the mark at node `j`
on the edge between `i` and `j`. So `m[i, j] == 2` with `m[j, i] == 3`
means `i --> j`. One pair of entries holds one edge, so self-loops and
parallel edges are rejected.

[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md) reads both
codings back.

## Usage

``` r
as_adjacency(x, coding = c("binary", "marks"))
```

## Arguments

- x:

  A `caugi` object.

- coding:

  Either `"binary"` for a 0/1 adjacency matrix or `"marks"` for the
  mark-coded `amat.pag` form.

## Value

An integer matrix with row/col names.

## See also

Other conversions:
[`as_bnlearn()`](https://caugi.org/dev/reference/as_bnlearn.md),
[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md),
[`as_dagitty()`](https://caugi.org/dev/reference/as_dagitty.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
adj <- as_adjacency(cg)

# Edges with circle or bidirected endpoints need the mark coding.
g <- caugi(A %o->% B, B %<->% C, class = "UNKNOWN")
m <- as_adjacency(g, coding = "marks")
m
#>   A B C
#> A 0 2 0
#> B 1 0 2
#> C 0 2 0
as_caugi(m, class = "UNKNOWN")
#> <caugi object; 3 nodes, 2 edges; simple: FALSE; session=0x5b8a8bca7070>
#>   graph_class: UNKNOWN
#>   nodes: A, B, C
#>   edges: Ao->B, B<->C
```
