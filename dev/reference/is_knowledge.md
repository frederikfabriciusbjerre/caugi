# Is it background knowledge?

Is it background knowledge?

## Usage

``` r
is_knowledge(x, throw_error = FALSE)
```

## Arguments

- x:

  An object.

- throw_error:

  Logical; if `TRUE`, error when `x` is not knowledge.

## Value

`TRUE` if `x` was made by
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md), else
`FALSE`.

## See also

Other knowledge:
[`knowledge()`](https://caugi.org/dev/reference/knowledge.md),
[`orient()`](https://caugi.org/dev/reference/orient.md),
[`required()`](https://caugi.org/dev/reference/required.md),
[`set_tiers()`](https://caugi.org/dev/reference/set_tiers.md),
[`tiers()`](https://caugi.org/dev/reference/tiers.md)

## Examples

``` r
is_knowledge(knowledge(A %-->% B)) # TRUE
#> [1] TRUE
is_knowledge(caugi(A %-->% B)) # FALSE
#> [1] FALSE
```
