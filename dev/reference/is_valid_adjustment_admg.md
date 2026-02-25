# Is a set a valid adjustment set in an ADMG?

Checks whether `Z` is a valid adjustment set for estimating the causal
effect of `X` on `Y` in an ADMG using the generalized adjustment
criterion.

## Usage

``` r
is_valid_adjustment_admg(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
)
```

## Arguments

- cg:

  A `caugi` object of class ADMG.

- X, Y:

  Node names (can be vectors for multiple treatments/outcomes).

- Z:

  Conditioning set (character vector of node names).

- X_index, Y_index, Z_index:

  Optional 1-based indices.

## Value

Logical value indicating if the adjustment set is valid.

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md),
[`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_backdoor()`](https://caugi.org/dev/reference/is_valid_backdoor.md),
[`minimal_d_separator()`](https://caugi.org/dev/reference/minimal_d_separator.md)

## Examples

``` r
# Classic confounding
cg <- caugi(
  L %-->% X,
  X %-->% Y,
  L %-->% Y,
  class = "ADMG"
)

is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = NULL) # FALSE
#> [1] FALSE
is_valid_adjustment_admg(cg, X = "X", Y = "Y", Z = "L") # TRUE
#> [1] TRUE
```
