# Compute a minimal d-separator

Computes a minimal d-separator Z for sets X and Y in a DAG, optionally
with mandatory inclusions and restrictions on the separator.

## Usage

``` r
minimal_d_separator(
  cg,
  X = NULL,
  Y = NULL,
  I = character(0),
  R = NULL,
  X_index = NULL,
  Y_index = NULL,
  I_index = NULL,
  R_index = NULL
)
```

## Source

van der Zander, B. & Liśkiewicz, M. (2020). Finding Minimal d-separators
in Linear Time and Applications. Proceedings of The 35th Uncertainty in
Artificial Intelligence Conference, in Proceedings of Machine Learning
Research 115:637-647 Available from
<https://proceedings.mlr.press/v115/van-der-zander20a.html>.

## Arguments

- cg:

  A `caugi` object (must be a DAG).

- X, Y:

  Node selectors: character vector of names or unquoted expression. Use
  `*_index` to pass 1-based indices.

- I:

  Nodes that must be included in the separator.

- R:

  Nodes allowed in the separator. If `NULL`, uses all nodes excluding X
  and Y.

- X_index, Y_index, I_index, R_index:

  Optional numeric 1-based indices (exclusive with corresponding name
  parameters).

## Value

A character vector of node names representing the minimal separator, or
`NULL` if no valid separator exists within the restriction R.

## Details

A d-separator Z for X and Y is a set of nodes such that conditioning on
Z d-separates X from Y in the graph. This function returns a minimal
separator, meaning no proper subset of Z still d-separates X and Y.

The algorithm:

1.  Restricts to ancestors of X ∪ Y ∪ I

2.  Computes initial separator candidate from R

3.  Refines using Bayes-ball d-connection algorithm

4.  Returns minimal separator or NULL if none exists within R

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md),
[`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md),
[`is_valid_backdoor()`](https://caugi.org/dev/reference/is_valid_backdoor.md)

## Examples

``` r
cg <- caugi(
  A %-->% X,
  X %-->% M,
  M %-->% Y,
  A %-->% Y,
  class = "DAG"
)

# Find any minimal separator between X and Y
minimal_d_separator(cg, "X", "Y")
#> [1] "A" "M"

# Force M to be in the separator
minimal_d_separator(cg, "X", "Y", I = "M")
#> [1] "A" "M"

# Restrict separator to only {A, M}
minimal_d_separator(cg, "X", "Y", R = c("A", "M"))
#> [1] "A" "M"
```
