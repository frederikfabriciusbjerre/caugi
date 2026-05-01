# Compute a minimal separator

Computes a minimal separator Z for sets X and Y, optionally with
mandatory inclusions and restrictions on the separator. Supports DAGs
(where the result is a d-separator), ADMGs, and ancestral graphs (where
the result is an m-separator).

## Usage

``` r
minimal_separator(
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

  A `caugi` object (DAG, ADMG, or AG).

- X, Y:

  Character vectors of node names. Use `*_index` to pass 1-based
  indices.

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

A separator Z for X and Y is a set of nodes such that conditioning on Z
d- or m-separates X from Y in the graph. This function returns a minimal
separator: no proper subset of Z (excluding I) still separates X and Y.

The algorithm runs in linear time O(n + m) and is unified across graph
classes via the Bayes-ball reachability of van der Zander & Liśkiewicz
(2020). For DAGs the algorithm specializes to FINDMINSEPINDAG; for ADMGs
and AGs (and their subclasses CPDAG, RCG, MAG) it uses the general
FINDMINSEP over mixed graphs.

## References

van der Zander, B. & Liśkiewicz, M. (2020). Finding Minimal d-separators
in Linear Time and Applications. In *Proceedings of the 35th Conference
on Uncertainty in Artificial Intelligence (UAI 2020)*, PMLR 115:637–647.
<https://proceedings.mlr.press/v115/van-der-zander20a.html>.

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
minimal_separator(cg, "X", "Y")
#> [1] "A" "M"

# Force M to be in the separator
minimal_separator(cg, "X", "Y", I = "M")
#> [1] "A" "M"

# Restrict separator to only {A, M}
minimal_separator(cg, "X", "Y", R = c("A", "M"))
#> [1] "A" "M"

# Works on ADMGs (returns a minimal m-separator)
admg <- caugi(
  X %-->% Y,
  L %-->% X,
  L %-->% Y,
  class = "ADMG"
)
minimal_separator(admg, "X", "Y")
#> NULL
```
