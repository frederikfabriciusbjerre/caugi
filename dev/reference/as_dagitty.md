# Convert a caugi to a dagitty graph

Convert a caugi to a dagitty graph

## Usage

``` r
as_dagitty(x)
```

## Arguments

- x:

  A `caugi` object.

## Value

A `dagitty` object.

## Details

The dagitty graph type is `dag`, `pdag`, `mag` or `pag`, picked from the
edge types. Node names are always quoted, so they may contain spaces or
edge symbols, with a few limits:

- dagitty rejects nodes named `node` or `graph`, so these raise an
  error.

- A `"` in a name is escaped. Backslashes are passed through as is,
  since dagitty keeps `\\` as two characters, so a name that ends in a
  backslash can't be written.

Reading a `pag` back with
[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md) gives class
`"UNKNOWN"`, as caugi doesn't support PAGs yet.

## See also

Other conversions:
[`as_adjacency()`](https://caugi.org/dev/reference/as_adjacency.md),
[`as_bnlearn()`](https://caugi.org/dev/reference/as_bnlearn.md),
[`as_caugi()`](https://caugi.org/dev/reference/as_caugi.md),
[`as_igraph()`](https://caugi.org/dev/reference/as_igraph.md)

## Examples

``` r
cg <- caugi(
  A %-->% B,
  class = "DAG"
)
g_dg <- as_dagitty(cg)
```
