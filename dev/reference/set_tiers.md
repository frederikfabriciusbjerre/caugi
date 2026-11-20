# Set the tiers or exogenous nodes of background knowledge

`set_tiers()` replaces the tiers, written as in `tier()` of
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md).
`set_exogenous()` replaces the exogenous nodes. Both add nodes they
name.

## Usage

``` r
set_tiers(bk, ..., tiers = NULL, max_lag)

set_exogenous(bk, ..., name = NULL)
```

## Arguments

- bk:

  Background knowledge, made by
  [`knowledge()`](https://caugi.org/dev/reference/knowledge.md).

- ...:

  Tiers, earliest first, such as `baseline = A + B`, or exogenous nodes.

- tiers:

  A list of character vectors, one per tier, instead of `...`.

- max_lag:

  Nodes in tiers more than `max_lag` apart are not adjacent. If missing,
  the current `max_lag` is kept. `NULL` removes it.

- name:

  A character vector of node names, instead of `...`.

## Value

The updated knowledge.

## See also

Other knowledge:
[`is_knowledge()`](https://caugi.org/dev/reference/is_knowledge.md),
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md),
[`orient()`](https://caugi.org/dev/reference/orient.md),
[`required()`](https://caugi.org/dev/reference/required.md),
[`tiers()`](https://caugi.org/dev/reference/tiers.md)

## Examples

``` r
bk <- knowledge(A %-->% B)
bk <- set_tiers(bk, baseline = A, followup = B + C)
set_exogenous(bk, A)
#> <knowledge; nodes: A, B, C>
#>   tier(baseline = A, followup = B + C)
#>   exogenous(A)
#>   A %-->% B
```
