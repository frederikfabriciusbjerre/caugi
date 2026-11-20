# Required and forbidden edges of background knowledge

The edges `bk` requires or forbids, as written, as a `caugi` of class
`"UNKNOWN"` on its nodes.

## Usage

``` r
required(bk)

forbidden(bk)
```

## Arguments

- bk:

  Background knowledge, made by
  [`knowledge()`](https://caugi.org/dev/reference/knowledge.md).

## Value

A `caugi`.

## See also

Other knowledge:
[`is_knowledge()`](https://caugi.org/dev/reference/is_knowledge.md),
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md),
[`orient()`](https://caugi.org/dev/reference/orient.md),
[`set_tiers()`](https://caugi.org/dev/reference/set_tiers.md),
[`tiers()`](https://caugi.org/dev/reference/tiers.md)

## Examples

``` r
bk <- knowledge(A %-->% B, !(B %-->% C), !(C %-->% B))
required(bk)
#> <caugi object; 3 nodes, 1 edges; simple: FALSE; session=0x5b62012dfb70>
#>   graph_class: UNKNOWN
#>   nodes: A, B, C
#>   edges: A-->B
forbidden(bk)
#> <caugi object; 3 nodes, 2 edges; simple: FALSE; session=0x5b6201189060>
#>   graph_class: UNKNOWN
#>   nodes: A, B, C
#>   edges: B-->C, C-->B
```
