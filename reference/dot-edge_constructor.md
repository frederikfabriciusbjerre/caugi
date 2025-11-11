# Edge constructor

Internal function to construct edges for `caugi` objects.

## Usage

``` r
.edge_constructor(from = character(), edge = character(), to = character())
```

## Arguments

- from:

  Character vector of source node names.

- edge:

  Character vector of edge glyphs.

- to:

  Character vector of target node names.

## Value

A `data.table` object with columns `from`, `edge`, and `to`.
