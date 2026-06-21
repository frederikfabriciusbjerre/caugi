# Compute an adjustment set

Computes an adjustment set for `X -> Y` in a DAG.

## Usage

``` r
adjustment_set(
  cg,
  X = NULL,
  Y = NULL,
  X_index = NULL,
  Y_index = NULL,
  type = c("optimal", "parents", "backdoor")
)
```

## Arguments

- cg:

  A `caugi` object.

- X, Y:

  Node names.

- X_index, Y_index:

  Optional numeric 1-based indices.

- type:

  One of `"parents"`, `"backdoor"`, `"optimal"`. The `optimal` option
  computes the O-set.

## Value

A character vector of node names representing the adjustment set.

## Details

Types supported:

- `"parents"`: \\\bigcup \mathrm{Pa}(X)\\ minus \\X \cup Y\\

- `"backdoor"`: an inclusion-minimal valid backdoor adjustment set,
  found in linear time as a minimal d-separator of `X` and `Y` in the
  proper backdoor graph (van der Zander, Liśkiewicz & Textor, 2019).
  Unlike `"parents"` (which always conditions on every parent of `X`),
  this drops nodes that are not needed to block a backdoor path. Note
  that minimal is not the same as statistically optimal; use `"optimal"`
  for the efficient O-set.

- `"optimal"`: O-set (only for single `x` and single `y`)

## See also

Other adjustment:
[`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md),
[`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md),
[`is_valid_backdoor()`](https://caugi.org/dev/reference/is_valid_backdoor.md),
[`minimal_separator()`](https://caugi.org/dev/reference/minimal_separator.md)

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

adjustment_set(cg, "X", "Y", type = "parents") # C, A
#> [1] "C" "A"
adjustment_set(cg, "X", "Y", type = "backdoor") # A
#> [1] "A"
adjustment_set(cg, "X", "Y", type = "optimal") # K
#> [1] "K"
```
