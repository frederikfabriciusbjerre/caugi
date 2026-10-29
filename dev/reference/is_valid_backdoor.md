# Is a backdoor set valid?

Checks whether `Z` satisfies the generalized back-door criterion
relative to `X` and `Y` in a DAG. `X` and `Y` can each hold one or more
nodes.

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

  Node names; one or more each, and disjoint.

- Z:

  Optional node set for conditioning

- X_index, Y_index, Z_index:

  Optional 1-based indices.

## Value

Logical value indicating if backdoor is valid or not.

## Details

`Z` satisfies the generalized back-door criterion (Maathuis & Colombo,
2015, Def. 3.7) when

1.  `Z` contains no descendant of `X`, and

2.  for every node \\X_i\\ in `X`, \\Z \cup X \setminus \\X_i\\\\ blocks
    every back-door path (a path starting with an edge into \\X_i\\)
    from \\X_i\\ to `Y`.

With one treatment and one outcome this is Pearl's back-door criterion.
With several treatments it can accept sets that Pearl's set version
rejects, since that version requires `Z` alone to block every back-door
path of each treatment. Every set accepted here is a valid adjustment
set, but a valid adjustment set may be rejected, for example one
containing a descendant of `X` off the causal paths. A `Z` that contains
a node of `X` or `Y` is never valid.

## References

Maathuis, M. H. & Colombo, D. (2015). A generalized back-door criterion.
*The Annals of Statistics*, 43(3), 1060–1088.
[doi:10.1214/14-AOS1295](https://doi.org/10.1214/14-AOS1295) .

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md),
[`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md),
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

is_valid_backdoor(cg, X = "X", Y = "Y", Z = NULL) # FALSE
#> [1] FALSE
is_valid_backdoor(cg, X = "X", Y = "Y", Z = "K") # TRUE
#> [1] TRUE
is_valid_backdoor(cg, X = "X", Y = "Y", Z = c("A", "C")) # TRUE
#> [1] TRUE

# Several treatments: X2 blocks X1 <-- X2 --> Y, so no adjustment is needed
cg2 <- caugi(X2 %-->% X1 + Y, X1 %-->% Y, class = "DAG")
is_valid_backdoor(cg2, X = c("X1", "X2"), Y = "Y", Z = NULL) # TRUE
#> [1] TRUE
```
