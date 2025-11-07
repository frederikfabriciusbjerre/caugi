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

A tibble with a `name` column (possibly 0 rows).

## Details

Types supported:

- `"parents"`: \\\bigcup \mathrm{Pa}(X)\\ minus \\X \cup Y\\

- `"backdoor"`: Pearl backdoor formula

- `"optimal"`: O-set (only for single `x` and single `y`)

## See also

Other adjustment:
[`all_backdoor_sets()`](https://frederikfabriciusbjerre.github.io/caugi/reference/all_backdoor_sets.md),
[`d_separated()`](https://frederikfabriciusbjerre.github.io/caugi/reference/d_separated.md),
[`is_valid_backdoor()`](https://frederikfabriciusbjerre.github.io/caugi/reference/is_valid_backdoor.md)

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
adjustment_set(cg, "X", "Y", type = "backdoor") # C, A
#> [1] "C" "A"
adjustment_set(cg, "X", "Y", type = "optimal") # K
#> [1] "K"
```
