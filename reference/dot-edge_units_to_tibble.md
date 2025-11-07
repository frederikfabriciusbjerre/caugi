# Turn edge units into a tibble of edges

Convert a list of edge units into a tibble with columns `from`, `edge`,
and `to`.

## Usage

``` r
.edge_units_to_tibble(units)
```

## Arguments

- units:

  A list of edge units, each with `lhs`, `rhs`, and `glyph`.

## Value

A tibble with columns `from`, `edge`, and `to`.
