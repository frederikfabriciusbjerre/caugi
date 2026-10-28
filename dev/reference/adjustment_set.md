# Compute an adjustment set

Computes an adjustment set for the effect of `X` on `Y` in a DAG. `X`
and `Y` can each hold one or more nodes.

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

  Node names; one or more each, and disjoint.

- X_index, Y_index:

  Optional numeric 1-based indices.

- type:

  One of `"parents"`, `"backdoor"`, `"optimal"`. The `optimal` option
  computes the O-set.

## Value

A character vector of node names representing the adjustment set.

## Details

Types supported:

- `"parents"`: \\\bigcup \mathrm{Pa}(X)\\ minus \\X \cup Y\\. With a
  single treatment this is valid whenever any valid set exists. With
  several treatments it can fail while other sets work, because a parent
  of one treatment can lie on a causal path from another.

- `"backdoor"`: an inclusion-minimal valid adjustment set, found in
  linear time as a minimal d-separator of `X` and `Y` in the proper
  backdoor graph (van der Zander, Liśkiewicz & Textor, 2019). It finds a
  valid set whenever one exists. Unlike `"parents"` (which always
  conditions on every parent of `X`), this drops nodes that are not
  needed to block a backdoor path. Note that minimal is not the same as
  statistically optimal; use `"optimal"` for the efficient O-set.

- `"optimal"`: the O-set \\\mathrm{Pa}(\mathrm{cn}(X, Y)) \setminus
  \mathrm{forb}(X, Y)\\ (Henckel, Perković & Maathuis, 2022). Following
  their Remark 3.14, nodes of `Y` that are not descendants of `X` are
  dropped with a warning, since the total effect on them is zero, and
  the O-set is computed for the rest of `Y`. It is then valid whenever
  any valid set exists. If no node of `Y` is a descendant of `X`, an
  error is raised. A dropped node can itself be in the O-set: for
  `X --> Y1 <-- Y2` with `Y = c("Y1", "Y2")`, `Y2` is dropped from `Y`
  and returned as the O-set, since it is a parent of `Y1`.

Every result is checked against the generalized adjustment criterion
(Perković et al., 2018). An error is raised when the requested set is
not valid. In particular, a valid set need not exist with several
treatments: in `X1 --> L --> X2`, `L --> Y`, only `L` blocks
`X2 <-- L --> Y`, but it lies on the causal path `X1 --> L --> Y`. With
a single treatment, no valid set exists only when a node of `Y` is a
parent of `X`.

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

# Several treatments
cg2 <- caugi(X1 %-->% W, W %-->% X2, X2 %-->% Y, U %-->% W + Y, class = "DAG")
adjustment_set(cg2, c("X1", "X2"), "Y", type = "optimal") # U
#> [1] "U"
```
