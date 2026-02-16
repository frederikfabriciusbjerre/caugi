# Build the `caugi` graph

Forces lazy compilation of the `caugi` graph without running a specific
query. Useful to pre-initialize the graph.

## Usage

``` r
build(cg)
```

## Arguments

- cg:

  A `caugi` object.

## Value

The input `caugi` object (invisibly), with its graph built.

## See also

Other verbs:
[`caugi_verbs`](https://caugi.org/dev/reference/caugi_verbs.md)

## Examples

``` r
cg <- caugi(A %-->% B, class = "DAG")
build(cg) # initialize graph without querying
```
