# Manipulate nodes and edges of a `caugi`

Add, remove, or and set nodes or edges to / from a `caugi` object. Edges
can be specified using expressions with the infix operators.
Alternatively, the edges to be added are specified using the `from`,
`edge`, and `to` arguments.

## Usage

``` r
add_edges(cg, ..., from = NULL, edge = NULL, to = NULL, inplace = FALSE)

remove_edges(cg, ..., from = NULL, edge = NULL, to = NULL, inplace = FALSE)

set_edges(cg, ..., from = NULL, edge = NULL, to = NULL, inplace = FALSE)

add_nodes(cg, ..., name = NULL, inplace = FALSE)

remove_nodes(cg, ..., name = NULL, inplace = FALSE)
```

## Arguments

- cg:

  A `caugi` object.

- ...:

  Expressions specifying edges to add using the infix operators, or
  nodes to add using unquoted names, vectors via
  [`c()`](https://rdrr.io/r/base/c.html), or `+` composition.

- from:

  Character vector of source node names. Default is `NULL`.

- edge:

  Character vector of edge types. Default is `NULL`.

- to:

  Character vector of target node names. Default is `NULL`.

- inplace:

  Logical, whether to modify the graph inplace or not. If `FALSE`
  (default), a copy of the `caugi` is made and modified.

- name:

  Character vector of node names. Default is `NULL`.

## Value

The updated `caugi`.

## Details

Caugi graph verbs

## Functions

- `add_edges()`: Add edges.

- `remove_edges()`: Remove edges.

- `set_edges()`: Set edge type for given pair(s).

- `add_nodes()`: Add nodes.

- `remove_nodes()`: Remove nodes.

## See also

Other verbs:
[`build()`](https://frederikfabriciusbjerre.github.io/caugi/reference/build.md)

## Examples

``` r
# initialize empty graph and build slowly
cg <- caugi(class = "PDAG")

cg <- cg |>
  add_nodes(c("A", "B", "C", "D", "E")) |> # A, B, C, D, E
  add_edges(A %-->% B %-->% C) |> # A --> B --> C, D, E
  set_edges(B %---% C) # A --> B --- C, D, E

cg <- remove_edges(cg, B %---% C) |> # A --> B, C, D, E
  remove_nodes(c("C", "D", "E")) # A --> B

# verbs do not build the Rust backend
cg@built # FALSE
#> [1] FALSE
build(cg)
#>      name
#>    <char>
#> 1:      A
#> 2:      B
#>      from   edge     to
#>    <char> <char> <char>
#> 1:      A    -->      B
cg@built # TRUE
#> [1] TRUE
```
