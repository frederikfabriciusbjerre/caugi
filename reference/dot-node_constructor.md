# Node constructor

A simple wrapper creating a `data.table` object with a single column
`name`.

## Usage

``` r
.node_constructor(names = character(), sort = FALSE)
```

## Arguments

- names:

  Character vector of node names.

- sort:

  Logical indicating whether to sort the node names.

## Value

A `data.table` object with a single column `name`.

## Details

The reason this exists is so if changes should be made in the future, it
is easy to simply change this constructor, rather than changing the
calls to `data.table` all over the place.
