# Manipulate nodes and edges of a `caugi`

Add, remove, or and set nodes or edges to / from a `caugi` object. Edges
can be specified using expressions with the infix operators.
Alternatively, the edges to be added are specified using the `from`,
`edge`, and `to` arguments. The same verbs edit background knowledge
made by [`knowledge()`](https://caugi.org/dev/reference/knowledge.md).

## Usage

``` r
add_edges(
  cg,
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  status = NULL,
  inplace = FALSE
)

remove_edges(
  cg,
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  status = NULL,
  inplace = FALSE
)

set_edges(
  cg,
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  status = NULL,
  inplace = FALSE
)

add_nodes(cg, ..., name = NULL, inplace = FALSE)

remove_nodes(cg, ..., name = NULL, inplace = FALSE)
```

## Arguments

- cg:

  A `caugi` object, or background knowledge.

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

- status:

  For background knowledge, with `from` and `to`: `"required"` or
  `"forbidden"`. By default, edges are added as required and removed in
  both kinds.

- inplace:

  DEPRECATED This parameter is deprecated and will be ignored. Graphs
  are always modified via copy-on-write.

- name:

  Character vector of node names. Default is `NULL`.

## Value

The updated `caugi` or knowledge.

## Details

Caugi graph verbs

## Functions

- `add_edges()`: Add edges.

- `remove_edges()`: Remove edges.

- `set_edges()`: Set edge type for given pair(s).

- `add_nodes()`: Add nodes.

- `remove_nodes()`: Remove nodes.

## See also

Other verbs: [`build()`](https://caugi.org/dev/reference/build.md)

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

# Graphs are now built lazily when needed
parents(cg, "B") # triggers compilation
#> [1] "A"

# background knowledge
bk <- knowledge(A %-->% B)
bk <- add_edges(bk, !(B %-->% C))
bk <- add_edges(bk, from = "C", to = "D", status = "forbidden")
remove_edges(bk, from = "A", to = "B")
#> <knowledge; nodes: A, B, C, D>
#>   !(B %-->% C)
#>   !(C %-->% D)
```
