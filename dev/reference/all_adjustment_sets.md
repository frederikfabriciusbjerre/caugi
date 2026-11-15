# Get all valid adjustment sets up to a certain size

Enumerates the sets that adjust for the effect of `X` on `Y`, up to size
`max_size`, which per default is 3.

## Usage

``` r
all_adjustment_sets(
  cg,
  X = NULL,
  Y = NULL,
  type = c("adjustment", "backdoor"),
  minimal = TRUE,
  max_size = 3L
)
```

## Arguments

- cg:

  A `caugi` object of class `"DAG"` or `"ADMG"`.

- X, Y:

  Node names; one or more each.

- type:

  `"adjustment"` (default) or `"backdoor"`; see Details.

- minimal:

  Logical; if `TRUE` (default), only minimal sets are returned.

- max_size:

  Integer; maximum size of sets to consider (default 3).

## Value

A list of character vectors, each a valid adjustment set (possibly
empty). The list is empty if no set qualifies, as when `X` and `Y`
overlap.

## Details

`type` picks the criterion:

- `"adjustment"` (default): the generalized adjustment criterion
  (Perković et al., 2018), which is complete, so every valid adjustment
  set up to `max_size` is found. Works on DAGs and ADMGs.

- `"backdoor"`: the generalized back-door criterion (Maathuis & Colombo,
  2015), as checked by `is_valid_adjustment(type = "backdoor")`. DAGs
  only.

Every back-door set is a valid adjustment set, but not the other way
round: in `X --> Y, X --> W`, `{W}` is a valid adjustment set but not a
back-door set, as `W` is a descendant of `X`.

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
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment()`](https://caugi.org/dev/reference/is_valid_adjustment.md),
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

all_adjustment_sets(cg, X = "X", Y = "Y") # {A}, {K}
#> [[1]]
#> [1] "A"
#> 
#> [[2]]
#> [1] "K"
#> 
all_adjustment_sets(cg, X = "X", Y = "Y", minimal = FALSE)
#> [[1]]
#> [1] "A"
#> 
#> [[2]]
#> [1] "K"
#> 
#> [[3]]
#> [1] "C" "A"
#> 
#> [[4]]
#> [1] "C" "K"
#> 
#> [[5]]
#> [1] "A" "K"
#> 
#> [[6]]
#> [1] "A" "F"
#> 
#> [[7]]
#> [1] "K" "F"
#> 
#> [[8]]
#> [1] "C" "A" "K"
#> 
#> [[9]]
#> [1] "C" "A" "F"
#> 
#> [[10]]
#> [1] "C" "K" "F"
#> 
#> [[11]]
#> [1] "A" "K" "F"
#> 

# A descendant of X off the causal paths is allowed, but not in a
# back-door set
cg2 <- caugi(X %-->% Y + W, class = "DAG")
all_adjustment_sets(cg2, "X", "Y", minimal = FALSE) # {}, {W}
#> [[1]]
#> character(0)
#> 
#> [[2]]
#> [1] "W"
#> 
all_adjustment_sets(cg2, "X", "Y", type = "backdoor", minimal = FALSE) # {}
#> [[1]]
#> character(0)
#> 

# ADMG
admg <- caugi(L %-->% X, X %-->% Y, L %-->% Y, M %<->% Y, class = "ADMG")
all_adjustment_sets(admg, X = "X", Y = "Y") # {L}
#> [[1]]
#> [1] "L"
#> 
```
