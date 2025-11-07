# Get nodes tibble from verb call.

Internal helper to build nodes tibble from verb call.

## Usage

``` r
.get_nodes_tibble(name, calls)
```

## Arguments

- name:

  Character vector of node names.

- calls:

  List of calls from `...`.

## Value

A tibble with column `name` for node names.
