# Get all valid adjustment sets in an ADMG

Enumerates all valid adjustment sets for estimating the causal effect of
`X` on `Y` in an ADMG, up to a specified maximum size.

## Usage

``` r
all_adjustment_sets_admg(
  cg,
  X = NULL,
  Y = NULL,
  X_index = NULL,
  Y_index = NULL,
  minimal = TRUE,
  max_size = 3L
)
```

## Arguments

- cg:

  A `caugi` object of class ADMG.

- X, Y:

  Node names (can be vectors for multiple treatments/outcomes).

- X_index, Y_index:

  Optional 1-based indices.

- minimal:

  Logical; if `TRUE` (default), only minimal sets are returned.

- max_size:

  Integer; maximum size of sets to consider (default 3).

## Value

A list of character vectors, each a valid adjustment set (possibly empty
list if none exist).

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_backdoor_sets()`](https://caugi.org/dev/reference/all_backdoor_sets.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md),
[`is_valid_backdoor()`](https://caugi.org/dev/reference/is_valid_backdoor.md),
[`minimal_d_separator()`](https://caugi.org/dev/reference/minimal_d_separator.md)

## Examples

``` r
cg <- caugi(
  L %-->% X,
  X %-->% Y,
  L %-->% Y,
  M %-->% Y,
  class = "ADMG"
)

all_adjustment_sets_admg(cg, X = "X", Y = "Y", minimal = TRUE)
#> [[1]]
#> [1] "L"
#> 
# Returns {L} as minimal adjustment set
```
