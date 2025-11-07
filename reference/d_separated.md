# Are X and Y d-separated given Z?

Checks whether every node in `X` is d-separated from every node in `Y`
given `Z` in a DAG.

## Usage

``` r
d_separated(
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

- X, Y, Z:

  Node selectors: character vector of names, unquoted expression
  (supports `+` and [`c()`](https://rdrr.io/r/base/c.html)), or `NULL`.
  Use `*_index` to pass 1-based indices. If `Z` is `NULL` or missing, no
  nodes are conditioned on.

- X_index, Y_index, Z_index:

  Optional numeric 1-based indices (exclusive with `X`,`Y`,`Z`
  respectively).

## Value

Logical scalar.

## See also

Other adjustment:
[`adjustment_set()`](https://frederikfabriciusbjerre.github.io/caugi/reference/adjustment_set.md),
[`all_backdoor_sets()`](https://frederikfabriciusbjerre.github.io/caugi/reference/all_backdoor_sets.md),
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

d_separated(cg, "X", "Y", Z = c("A", "D")) # TRUE
#> [1] TRUE
d_separated(cg, "X", "Y", Z = NULL) # FALSE
#> [1] FALSE
```
