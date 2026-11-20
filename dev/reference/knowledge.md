# Background knowledge

Background knowledge about a causal graph: required and forbidden edges,
tiers and exogenous nodes.

## Usage

``` r
knowledge(..., nodes = NULL)
```

## Arguments

- ...:

  Statements, as above, or bare node names.

- nodes:

  Character vector of node names. If given, the knowledge is about
  exactly these nodes: no statement, and no later edit, may name
  another.

## Value

A `caugi_knowledge` object.

## Details

Statements:

- `A %-->% B`: the edge `A --> B` is required.

- `!(A %-->% B)`: the edge `A --> B` is forbidden. The parentheses are
  required, and `!` applies to each edge inside them.

- `tier(t1 = A + B, t2 = C, max_lag = NULL)`: edges between tiers point
  from the earlier tier to the later one, and nodes in tiers more than
  `max_lag` apart are not adjacent. Nodes without a tier are not
  constrained by it.

- `exogenous(A, B)`: no edge points into A or B.

Edges are written as in
[`caugi()`](https://caugi.org/dev/reference/caugi.md), so
`A + B %-->% C` and `A %-->% B %-->% C` work too.

## See also

Other knowledge:
[`is_knowledge()`](https://caugi.org/dev/reference/is_knowledge.md),
[`orient()`](https://caugi.org/dev/reference/orient.md),
[`required()`](https://caugi.org/dev/reference/required.md),
[`set_tiers()`](https://caugi.org/dev/reference/set_tiers.md),
[`tiers()`](https://caugi.org/dev/reference/tiers.md)

## Examples

``` r
bk <- knowledge(
  tier(baseline = A + B, followup = C + D),
  A %-->% C,
  !(B %-->% D),
  exogenous(A)
)
bk
#> <knowledge; nodes: A, B, C, D>
#>   tier(baseline = A + B, followup = C + D)
#>   exogenous(A)
#>   A %-->% C
#>   !(B %-->% D)
edges(bk, expand = TRUE)
plot(bk)

```
