# Is a backdoor set valid?

Checks whether `Z` is a valid backdoor adjustment set for `X --> Y`.

## Usage

``` r
is_valid_backdoor(
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

  A `caugi` object.

- X, Y:

  Single node names.

- Z:

  Optional node set for conditioning

- X_index, Y_index, Z_index:

  Optional 1-based indices.

## Value

Logical value indicating if backdoor is valid or not.

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md),
[`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md),
[`minimal_d_separator()`](https://caugi.org/dev/reference/minimal_d_separator.md)

## Examples

``` r
cg <- caugi(
  C %-->% X,
  X %-->% F,
  X %-->% D,
  A %-->% X,
  A %-->% K,
  K %-->% Y,
  D %-->% Y,
  D %-->% G,
  Y %-->% H,
  class = "DAG"
)

is_valid_backdoor(cg, X = "X", Y = "Y", Z = NULL) # FALSE
#> [1] FALSE
is_valid_backdoor(cg, X = "X", Y = "Y", Z = "K") # TRUE
#> [1] TRUE
is_valid_backdoor(cg, X = "X", Y = "Y", Z = c("A", "C")) # TRUE
#> [1] TRUE
```
