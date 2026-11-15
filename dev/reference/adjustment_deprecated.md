# Deprecated adjustment functions

These functions are deprecated and will be removed in caugi 2.0.0:

- `is_valid_backdoor()`: use `is_valid_adjustment(type = "backdoor")`.

- `is_valid_adjustment_admg()`: use
  [`is_valid_adjustment()`](https://caugi.org/dev/reference/is_valid_adjustment.md).

- `all_backdoor_sets()`: use `all_adjustment_sets(type = "backdoor")`.

- `all_adjustment_sets_admg()`: use
  [`all_adjustment_sets()`](https://caugi.org/dev/reference/all_adjustment_sets.md).

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

is_valid_adjustment_admg(
  cg,
  X = NULL,
  Y = NULL,
  Z = NULL,
  X_index = NULL,
  Y_index = NULL,
  Z_index = NULL
)

all_backdoor_sets(
  cg,
  X = NULL,
  Y = NULL,
  X_index = NULL,
  Y_index = NULL,
  minimal = TRUE,
  max_size = 3L
)

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

  A `caugi` object.

- X, Y:

  Node names; one or more each.

- Z:

  See
  [`is_valid_adjustment()`](https://caugi.org/dev/reference/is_valid_adjustment.md).

- X_index, Y_index, Z_index:

  Deprecated; pass node names instead.

- minimal, max_size:

  See
  [`all_adjustment_sets()`](https://caugi.org/dev/reference/all_adjustment_sets.md).

## Value

See
[`is_valid_adjustment()`](https://caugi.org/dev/reference/is_valid_adjustment.md)
and
[`all_adjustment_sets()`](https://caugi.org/dev/reference/all_adjustment_sets.md).
