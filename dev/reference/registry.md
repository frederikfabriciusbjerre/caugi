# `caugi` edge registry

The `caugi` edge registry stores information about the different edge
types that can be used in `caugi` graphs. It maps edge glyphs (e.g.,
`"-->"`, `"<->"`, `"o->"`, etc.) to their specifications, including tail
and head marks, class, and symmetry. The registry allows for dynamic
registration of new edge types, enabling users to extend the set of
supported edges in `caugi.` It is implemented as a singleton, ensuring
that there is a single global instance of the registry throughout the R
session.

## Usage

``` r
caugi_registry()

list_caugi_edges()

reset_caugi_registry()

seal_caugi_registry()
```

## Value

An `edge_registry` external pointer.

A `data.table` with columns `glyph`, `tail`, `head`, `class`, and
`symmetric`, where each row corresponds to a registered edge type.

## Details

The intended use of the `caugi` registry is mostly for advanced users
and developers. The registry enables users who need to define their own
custom edge types in `caugi` directly. It currently mostly supports the
*representation* of new edges. The reverse edges `<--`, `<-o` and `o--`
are built in: `B %<--% A` is stored as `A %-->% B`.

## Functions

- `caugi_registry()`: Access the global edge registry, creating it if
  needed.

- `list_caugi_edges()`: List all registered edge types in the global
  registry.

- `reset_caugi_registry()`: Reset the global edge registry to its
  default state.

- `seal_caugi_registry()`: Seal the global edge registry to prevent
  further modifications.

## See also

Other registry:
[`register_caugi_edge()`](https://caugi.org/dev/reference/register_caugi_edge.md)

## Examples

``` r
# first, for reproducability, we reset the registry to default
reset_caugi_registry()

# create a new registry
reg <- caugi_registry()

# list registered edges
list_caugi_edges()
#>     glyph   tail   head                class symmetric
#>    <char> <char> <char>               <char>    <lgcl>
#> 1:    -->   tail  arrow             directed     FALSE
#> 2:    ---   tail   tail           undirected      TRUE
#> 3:    <->  arrow  arrow           bidirected      TRUE
#> 4:    o-o circle circle              partial      TRUE
#> 5:    --o   tail circle partially_undirected     FALSE
#> 6:    o-> circle  arrow   partially_directed     FALSE
#> 7:    <--  arrow   tail             directed     FALSE
#> 8:    <-o  arrow circle   partially_directed     FALSE
#> 9:    o-- circle   tail partially_undirected     FALSE

# register an edge: causalDisco writes forbidden edges in background
# knowledge as `!-->`
register_caugi_edge(
  glyph = "!-->",
  tail_mark = "tail",
  head_mark = "arrow",
  class = "directed",
  symmetric = FALSE
)

# now, this edge is available for caugi graphs:
list_caugi_edges()
#>      glyph   tail   head                class symmetric
#>     <char> <char> <char>               <char>    <lgcl>
#>  1:    -->   tail  arrow             directed     FALSE
#>  2:    ---   tail   tail           undirected      TRUE
#>  3:    <->  arrow  arrow           bidirected      TRUE
#>  4:    o-o circle circle              partial      TRUE
#>  5:    --o   tail circle partially_undirected     FALSE
#>  6:    o-> circle  arrow   partially_directed     FALSE
#>  7:    <--  arrow   tail             directed     FALSE
#>  8:    <-o  arrow circle   partially_directed     FALSE
#>  9:    o-- circle   tail partially_undirected     FALSE
#> 10:   !-->   tail  arrow             directed     FALSE
cg <- caugi(A %-->% B, B %!-->% C, class = "UNKNOWN")

# reset the registry to default
reset_caugi_registry()
```
