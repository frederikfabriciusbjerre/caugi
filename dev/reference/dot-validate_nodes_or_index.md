# Validate nodes or index argument

Check that either nodes or index is supplied, but not both.

## Usage

``` r
.validate_nodes_or_index(nodes_missing, index, index_missing)
```

## Arguments

- nodes_missing:

  Logical; result of `missing(nodes)`.

- index:

  An index argument.

- index_missing:

  Logical; result of `missing(index)`.

## Value

A list with `nodes_supplied` and `index_supplied` logical values.
