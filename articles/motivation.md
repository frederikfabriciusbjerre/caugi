# Motivation

Why another graph package in R? The `caugi` package was designed to
provide a *fast*, *flexible*, and *causality-first* graph interface.

``` r
library(caugi)
```

## Representation of causal graphs

Causal graphs are easy to draw and aid us in understanding causal
mechanisms by visual representation. In R, representing them can feel
clunky. Historically, users have resorted to adjacency matrices, edge
lists, or packages like `igraph` or `graph`.

These tools are great and each have their strengths, but they are not
built for *causal* graphs, which often have special edge types and
properties. This leads to situations such as representing undirected
edges as two directed edges going in each direction, or representing
PAG-type edges by opaque matrix formats, as seen in for example `pcalg`,
where

``` r
nodes <- c("A", "B", "C", "D", "E")
amat <- matrix(
  c(
    0L, 2L, 0L, 0L, 1L,
    3L, 0L, 2L, 1L, 0L,
    0L, 1L, 0L, 0L, 3L,
    0L, 1L, 0L, 0L, 3L,
    3L, 0L, 3L, 3L, 0L
  ),
  5, 5,
  byrow = TRUE, dimnames = list(nodes, nodes)
)
amat
#>   A B C D E
#> A 0 2 0 0 1
#> B 3 0 2 1 0
#> C 0 1 0 0 3
#> D 0 1 0 0 3
#> E 3 0 3 3 0
```

represents the graph

``` r
caugi(
  A %-->% B %o->% C %---% E,
  B %o-o% D %---% E,
  A %--o% E
)
```

The second form reads like the picture in your head.

For people working in causal inference and causal discovery, the lack of
readable, well supported formats can lead to clunky, hacky code that is
hard to read and maintain. `caugi` aims to fix this with a readable
syntax, which mimics how we draw graphs by hand, and gives the user the
ability to express complex causal relationships.

## Safety

When makeshift solutions are used to represent causal graphs, it leads
to not only bugs, but confusion and wasted time. With `caugi` we aim to
make causal graphs safe to work with, so you do not accidentally create
invalid graphs, and so you can focus on the causal problems at hand, not
on the representation.

We have ensured that the `caugi` graph object should be impossible to
alter in such a way that the underlying graph class becomes invalid. For
example, creating a DAG with `caugi`, acyclicity is guaranteed by
construction. Trying to add an edge that would create a cycle will throw
an error.

More generally, `caugi` aims to be **graph-class safe**. Think of it as
type safety, but on a graph-class level. This safety comes at some
costs; if `caugi` doesn’t support the graph type you are using, then the
graph class should be set to `"UNKNOWN"`, and most operations will not
be available, since the interpretation of the relationships described by
the graph is *unknown* to `caugi`. However, this is a small price to pay
for safety and clarity. In `caugi`, we prefer clarity over silent
misinterpretation. `caugi` will act as your causality guard dog 🐶

We refer to the vignette
[`vignette("package_use")`](https://frederikfabriciusbjerre.github.io/caugi/articles/package_use.md)
to see how to (safely) use `caugi` in your package.

## Performance

Due to the underlying data structure of `caugi`, the graph objects are
fast to query, but slower to initialize than other graph object types
might be. The trade-off is favorable, as graphs are typically queried
many times after being created once. This makes `caugi` suitable for
large graphs, where performance matters, but even for small graphs the
performance gain is significant to other packages.

You can read more about the performance of `caugi` in
[`vignette("performance")`](https://frederikfabriciusbjerre.github.io/caugi/articles/performance.md).
