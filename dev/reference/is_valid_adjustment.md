# Is a set a valid adjustment set?

Checks whether `Z` is a valid adjustment set for the effect of `X` on
`Y`. `X` and `Y` can each hold one or more nodes.

## Usage

``` r
is_valid_adjustment(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  type = c("adjustment", "backdoor")
)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"` or `"ADMG"`.

- X, Y:

  Node names; one or more each.

- Z:

  Node names of the candidate adjustment set; `NULL` (default) or
  `character(0)` for the empty set.

- type:

  `"adjustment"` (default) or `"backdoor"`; see Details.

## Value

`TRUE` if `Z` is a valid adjustment set, `FALSE` otherwise.

## Details

`type` picks the criterion:

- `"adjustment"` (default): the generalized adjustment criterion
  (Perković et al., 2018), which is complete, so it accepts exactly the
  valid adjustment sets. Works on DAGs and ADMGs.

- `"backdoor"`: the generalized back-door criterion (Maathuis & Colombo,
  2015, Def. 3.7). DAGs only. `Z` satisfies it when

  1.  `Z` contains no descendant of `X`, and

  2.  for every node \\X_i\\ in `X`, \\Z \cup X \setminus \\X_i\\\\
      blocks every back-door path (a path starting with an edge into
      \\X_i\\) from \\X_i\\ to `Y`.

  With one treatment and one outcome this is Pearl's back-door
  criterion. With several treatments it can accept sets that Pearl's set
  version rejects, since that version requires `Z` alone to block every
  back-door path of each treatment.

Every back-door set is a valid adjustment set, but not the other way
round: in `X --> Y, X --> W`, `{W}` is a valid adjustment set but not a
back-door set, as `W` is a descendant of `X`. `X`, `Y` and `Z` must be
pairwise disjoint, so overlapping sets give `FALSE`.

## References

Perković, E., Textor, J., Kalisch, M. & Maathuis, M. H. (2018). Complete
graphical characterization and construction of adjustment sets in Markov
equivalence classes of ancestral graphs. *Journal of Machine Learning
Research*, 18(220), 1–62.

Maathuis, M. H. & Colombo, D. (2015). A generalized back-door criterion.
*The Annals of Statistics*, 43(3), 1060–1088.
[doi:10.1214/14-AOS1295](https://doi.org/10.1214/14-AOS1295) .

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_adjustment_sets()`](https://caugi.org/dev/reference/all_adjustment_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
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

is_valid_adjustment(cg, X = "X", Y = "Y", Z = NULL) # FALSE
#> [1] FALSE
is_valid_adjustment(cg, X = "X", Y = "Y", Z = "K") # TRUE
#> [1] TRUE
is_valid_adjustment(cg, X = "X", Y = "Y", Z = c("A", "C")) # TRUE
#> [1] TRUE

# A descendant of X off the causal paths is allowed, but not in a
# back-door set
cg2 <- caugi(X %-->% Y + W, class = "DAG")
is_valid_adjustment(cg2, "X", "Y", "W") # TRUE
#> [1] TRUE
is_valid_adjustment(cg2, "X", "Y", "W", type = "backdoor") # FALSE
#> [1] FALSE

# Several treatments: X2 blocks X1 <-- X2 --> Y, so no adjustment is needed
cg3 <- caugi(X2 %-->% X1 + Y, X1 %-->% Y, class = "DAG")
is_valid_adjustment(cg3, X = c("X1", "X2"), Y = "Y", Z = NULL) # TRUE
#> [1] TRUE

# ADMG
admg <- caugi(L %-->% X, X %-->% Y, L %-->% Y, class = "ADMG")
is_valid_adjustment(admg, X = "X", Y = "Y", Z = "L") # TRUE
#> [1] TRUE
```
