# Turn edge units into a `data.table` of edges

Convert a list of edge units into a `data.table` with columns `from`,
`edge`, and `to`.

## Usage

``` r
.edge_units_to_dt(units)
```

## Arguments

- units:

  A list of edge units, each with `lhs`, `rhs`, and `glyph`.

## Value

A `data.table` with columns `from`, `edge`, and `to`.
