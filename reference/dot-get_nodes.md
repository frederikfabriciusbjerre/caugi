# Get nodes `data.table` from verb call.

Internal helper to build nodes `data.table` from verb call.

## Usage

``` r
.get_nodes(name, calls)
```

## Arguments

- name:

  Character vector of node names.

- calls:

  List of calls from `...`.

## Value

A `data.table` with column `name` for node names.
