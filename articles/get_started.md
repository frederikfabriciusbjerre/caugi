# Get started

``` r
# load the package
library(caugi)
```

In this vignette, we will walk you through how to create a `caugi`,
query it, modify it, and then compare it to other `caugi`s.

## The `caugi` object

You can create a `caugi` graph object using the
[`caugi()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi.md)
function along with infix operators to define edges. Let’s create a
directed acyclic graph (DAG) with 5 nodes and 5 edges.

``` r
cg <- caugi(
  A %-->% B %-->% C + D,
  A %-->% C,
  class = "DAG"
)
cg
#>      name
#>    <char>
#> 1:      A
#> 2:      B
#> 3:      C
#> 4:      D
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    -->      B
#> 2:      B    -->      C
#> 3:      B    -->      D
#> 4:      A    -->      C
```

You might scratch your head a bit, when looking at the call above. To
clarify, `A %-->% B` creates the edge `-->` from `A` to `B`. The syntax
`B %-->% C + D` is equivalent to `B %--> C` *and* `B %-->% D`. Notice
that the graph prints two `tibbles`. The first is equivalent to
`cg@nodes` and the second `cg@edges`. Besides that, the `caugi` holds
other *properties*. Let’s check the other properties.

### Properties

#### `ptr`

``` r
cg@ptr
#> <pointer: 0x55f8c355b970>
```

This is the pointer to the Rust object that `caugi` utilizes for
performance.

#### `simple`

``` r
cg@simple
#> [1] TRUE
```

This indicates whether the graph is *simple* or not. Let’s try to create
a non-simple graph:

``` r
caugi(A %-->% B, B %-->% A)
#> Error in graph_builder_add_edges(b, as.integer(unname(id[edges$from])), : parallel edges not allowed in simple graphs
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
#>      name
#>    <char>
#> 1:      A
#> 2:      B
#> 3:      C
#> 4:      D
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    -->      C
#> 2:      B    -->      A
#> 3:      D    -->      C
```

Would you like to add nodes? Then use
[`add_nodes()`](https://frederikfabriciusbjerre.github.io/caugi/reference/caugi_verbs.md).

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
[`vignette("package_use")`](https://frederikfabriciusbjerre.github.io/caugi/articles/package_use.md)
and
[`vignette("performance")`](https://frederikfabriciusbjerre.github.io/caugi/articles/performance.md)
to see how to use `caugi` in your own packages, and to see how `caugi`
performs compared to other graph packages in R. For the interested
reader, we also recommend
[`vignette("motivation")`](https://frederikfabriciusbjerre.github.io/caugi/articles/motivation.md),
which goes deeper into the motivation behind `caugi` and what we aspire
to do with `caugi`.

## Appendix

### Advanced properties

#### `built`

``` r
cg@built
#> [1] TRUE
```

This indicates whether the graph has been “built” or not on the Rust
side. This is important, as the Rust object may not agree with the R
object if `built = FALSE`.

#### `name_index_map`

``` r
cg@name_index_map
```

The `name_index_map` is a hashmap that takes node names as keys and
outputs zero-based indices. This is used to access nodes’ zero-based
indices, when converting node names to indices for Rust calls, as the
Rust backend uses zero-based indices.

#### `.state`

``` r
cg@.state
#> <environment: 0x55f8c681b0b0>
```

This is the internal state of the `caugi` graph object. It is used to
ensure that the `caugi` object can be modified in R and, so to speak,
*saves* the modifications you might make to the graph in R without
having to rebuild the graph in Rust each time. The most important
takeaway about the state is that you should *avoid* modifying the state
directly. Instead, you should use the verbs.
