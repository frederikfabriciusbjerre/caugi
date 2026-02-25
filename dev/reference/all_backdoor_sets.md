# Get all backdoor sets up to a certain size.

This function returns the backdoor sets up to size `max_size`, which per
default is set to 10.

## Usage

``` r
all_backdoor_sets(
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

  A `caugi`.

- X, Y:

  Single node name.

- X_index, Y_index:

  Optional 1-based indices (exclusive with name args).

- minimal:

  Logical; if `TRUE` (default), only minimal sets are returned.

- max_size:

  Integer; maximum size of sets to consider (default 3).

## Value

A list of character vectors, each an adjustment set (possibly empty).

## See also

Other adjustment:
[`adjustment_set()`](https://caugi.org/dev/reference/adjustment_set.md),
[`all_adjustment_sets_admg()`](https://caugi.org/dev/reference/all_adjustment_sets_admg.md),
[`d_separated()`](https://caugi.org/dev/reference/d_separated.md),
[`is_valid_adjustment_admg()`](https://caugi.org/dev/reference/is_valid_adjustment_admg.md),
[`is_valid_backdoor()`](https://caugi.org/dev/reference/is_valid_backdoor.md),
[`minimal_d_separator()`](https://caugi.org/dev/reference/minimal_d_separator.md)

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

all_backdoor_sets(cg, X = "X", Y = "Y", max_size = 3L, minimal = FALSE)
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
#> [1] "C" "A" "K"
#> 
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
#> [1] "C" "A" "K"

all_backdoor_sets(cg, X = "X", Y = "Y", max_size = 3L, minimal = TRUE)
#> [[1]]
#> [1] "A"
#> 
#> [[2]]
#> [1] "K"
#> 
#> [[1]]
#> [1] "A"
#>
#> [[2]]
#> [1] "K"
```
