# caugi

``` r
# load the package
library(caugi)
```

In this vignette, we will walk you through how to create a `caugi`,
query it, modify it, and then compare it to other `caugi`s.

## The `caugi` object

You can create a `caugi` graph object using the
[`caugi()`](https://caugi.org/dev/reference/caugi.md) function along
with infix operators to define edges. Let’s create a directed acyclic
graph (DAG) with 5 nodes and 5 edges.

``` r
cg <- caugi(
  A %-->% B %-->% C + D,
  A %-->% C,
  class = "DAG"
)
cg
#> <caugi object; 4 nodes, 4 edges; simple: TRUE; session=0x563e46feac60>
#>   graph_class: DAG
#>   nodes: A, B, C, D
#>   edges: A-->B, A-->C, B-->C, B-->D
```

You might scratch your head a bit, when looking at the call above. To
clarify, `A %-->% B` creates the edge `-->` from `A` to `B`. The syntax
`B %-->% C + D` is equivalent to `B %-->% C` *and* `B %-->% D`. Notice
that the graph prints two `tibbles`. The first is equivalent to
`cg@nodes` and the second `cg@edges`. Besides that, the `caugi` holds
other *properties*. Let’s check the other properties.

### Properties

#### `session`

``` r
cg@session
#> <pointer: 0x563e46feac60>
```

This is the session pointer to the Rust graph object that `caugi`
utilizes for performance. The session manages lazy compilation and
caching of graph operations internally.

#### `simple`

``` r
cg@simple
#> [1] TRUE
```

This indicates whether the graph is *simple* or not. Let’s try to create
a non-simple graph:

``` r
caugi(A %-->% B, B %-->% A)
#> Error in `rs_resolve_class()`:
#> ! Parallel edges not allowed in simple graphs (A -> B)
```

This cannot be done unless you initialize the graph with
`simple = FALSE`. Note that, currently, all of the supported graph
classes only support `simple = TRUE` unless the class is `UNKNOWN`.

#### `graph_class`

``` r
cg@graph_class
#> [1] "DAG"
```

This is the graph’s class. As you can see here, it is a DAG.

## Querying the `caugi`

We can query the `caugi` graph object with the built-in queries provided
in the package. Let’s try to find the descendants of all the parents of
the node `C`:

``` r
descendants(cg, parents(cg, "C"))
#> $A
#> [1] "B" "C" "D"
#> 
#> $B
#> [1] "C" "D"
```

First note that the output is a list of named character vectors. How
come? Since the parents of `C` is `c(A, B)`:

``` r
parents(cg, "C")
#> [1] "A" "B"
```

So for each parent of `C` we have a named vector in the list that
represents the descendants of that parent node.

## Modifying the `caugi`

Let’s try to modify the graph from before, so we get a new DAG.

``` r
cg_modified <- cg |>
  remove_edges(A %-->% B, B %-->% C + D) |>
  add_edges(B %-->% A, D %-->% C)
cg_modified
#> <caugi object; 4 nodes, 3 edges; simple: TRUE; session=0x563e4a1d1060>
#>   graph_class: DAG
#>   nodes: A, B, C, D
#>   edges: A-->C, B-->A, D-->C
```

Would you like to add nodes? Then use
[`add_nodes()`](https://caugi.org/dev/reference/caugi_verbs.md).

## Graph metrics

Now that we have two different graphs, we can use different metrics to
measure the difference between the two graphs. Here, we use the
adjustment identification distance (AID) and the structural Hamming
distance (SHD):

``` r
aid(cg, cg_modified)
#> [1] 0.5833333
shd(cg, cg_modified, normalized = TRUE)
#> [1] 0.6666667
```

## There you go!

You have now created a graph, inspected it, modified it, and measured
the difference between the two graphs – both structurally and
interventionally.

For further reading, we recommend the vignettes
[`vignette("package_use")`](https://caugi.org/dev/articles/package_use.md)
and [performance article](https://caugi.org/articles/performance.html)
on our website to see how to use `caugi` in your own packages, and to
see how `caugi` performs compared to other graph packages in R. For the
interested reader, we also recommend
[`vignette("motivation")`](https://caugi.org/dev/articles/motivation.md),
which goes deeper into the motivation behind `caugi` and what we aspire
to do with `caugi`.

## Appendix

### Advanced properties

#### `name_index_map`

#### `session`

``` r
cg@session
#> <pointer: 0x563e46feac60>
```

This is the Rust GraphSession pointer that holds the canonical graph
state. The session handles lazy compilation and caching of graph
operations internally. You should *avoid* accessing or modifying the
session directly. Instead, use the provided accessor properties
(`@nodes`, `@edges`, `@simple`, `@graph_class`) and verb functions
([`add_edges()`](https://caugi.org/dev/reference/caugi_verbs.md),
[`remove_nodes()`](https://caugi.org/dev/reference/caugi_verbs.md),
etc.).
