# Length of a `caugi`

Returns the number of nodes in the graph.

## Arguments

- x:

  A `caugi` object.

## Value

An integer representing the number of nodes.

## See also

Other caugi methods:
[`print()`](https://caugi.org/dev/reference/print.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
length(cg) # 2
#> [1] 2

cg2 <- caugi(
  A %-->% B + C,
  nodes = LETTERS[1:5],
  class = "DAG"
)
length(cg2) # 5
#> [1] 5
```
