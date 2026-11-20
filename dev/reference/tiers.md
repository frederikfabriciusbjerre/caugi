# Tiers of background knowledge

Tiers of background knowledge

## Usage

``` r
tiers(bk)
```

## Arguments

- bk:

  Background knowledge, made by
  [`knowledge()`](https://caugi.org/dev/reference/knowledge.md).

## Value

A named list of node names per tier, earliest tier first.

## See also

Other knowledge:
[`is_knowledge()`](https://caugi.org/dev/reference/is_knowledge.md),
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md),
[`orient()`](https://caugi.org/dev/reference/orient.md),
[`required()`](https://caugi.org/dev/reference/required.md),
[`set_tiers()`](https://caugi.org/dev/reference/set_tiers.md)

## Examples

``` r
tiers(knowledge(tier(baseline = A + B, followup = C)))
#> $baseline
#> [1] "A" "B"
#> 
#> $followup
#> [1] "C"
#> 
```
