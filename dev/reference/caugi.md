# Create a `caugi` from edge expressions.

Create a `caugi` from a series of edge expressions using infix
operators. Nodes can be specified as symbols, strings, or numbers.

The following edge operators are supported by default:

- `%-->%` for directed edges (A –\> B)

- `%---%` for undirected edges (A — B)

- `%<->%` for bidirected edges (A \<-\> B)

- `%o->%` for partially directed edges (A o-\> B)

- `%--o%` for partially undirected edges (A –o B)

- `%o-o%` for partial edges (A o-o B)

You can register additional edge types using
[`register_caugi_edge()`](https://caugi.org/dev/reference/register_caugi_edge.md).

## Usage

``` r
caugi(
  ...,
  from = NULL,
  edge = NULL,
  to = NULL,
  nodes = NULL,
  edges_df = NULL,
  simple = TRUE,
  build = TRUE,
  class = c("AUTO", "DAG", "UG", "PDAG", "ADMG", "AG", "UNKNOWN"),
  state = NULL
)
```

## Arguments

- ...:

  Edge expressions using the supported infix operators, or nodes given
  by symbols or strings. Multiple edges can be combined using `+`:
  `A --> B + C`, indicating an edge from `A` to both `B` and `C`. Nodes
  can also be grouped using `c(...)` or parentheses.

- from:

  Character vector of source node names. Optional; mutually exclusive
  with `...`.

- edge:

  Character vector of edge types. Optional; mutually exclusive with
  `...`.

- to:

  Character vector of target node names. Optional; mutually exclusive
  with `...`.

- nodes:

  Character vector of node names to declare as isolated nodes. An
  optional, but recommended, option is to provide all node names in the
  graph, including those that appear in edges. If `nodes` is provided,
  the order of nodes in the graph will follow the order in `nodes`.

- edges_df:

  Optional data.frame or data.table with columns `from`, `edge`, and
  `to` to specify edges. Mutually exclusive with `...` and `from`,
  `edge`, `to`. Can be used to create graphs using `edges(cg)` from
  another `caugi` object, `cg`.

- simple:

  Logical; if `TRUE` (default), the graph is a simple graph, and the
  function will throw an error if the input contains parallel edges or
  self-loops.

- build:

  Logical; if `TRUE` (default), the graph will be built using the Rust
  backend. If `FALSE`, the graph will not be built, and the Rust backend
  cannot be used. The graph will build, when queries are made to the
  graph or if calling
  [`build()`](https://caugi.org/dev/reference/build.md). **Note**: Even
  if `build = TRUE`, if no edges or nodes are provided, the graph will
  not be built and the pointer will be `NULL`.

- class:

  Character; one of `"AUTO"`, `"DAG"`, `"UG"`, `"PDAG"`, `"ADMG"`,
  `"AG"`, or `"UNKNOWN"`. `"AUTO"` will automatically pick the
  appropriate class based on the first match in the order of `"DAG"`,
  `"UG"`, `"PDAG"`, `"ADMG"`, and `"AG"`. It will default to `"UNKNOWN"`
  if no match is found.

- state:

  For internal use. Build a graph by supplying a pre-constructed state
  environment.

## Value

A `caugi` S7 object containing the nodes, edges, and a pointer to the
underlying Rust graph structure.

## Examples

``` r
# create a simple DAG (using NSE)
cg <- caugi(
  A %-->% B + C,
  B %-->% D,
  class = "DAG"
)

# create a PDAG with undirected edges (using NSE)
cg2 <- caugi(
  A %-->% B + C,
  B %---% D,
  E, # no neighbors for this node
  class = "PDAG"
)

# create a DAG (using SE)
cg3 <- caugi(
  from = c("A", "A", "B"),
  edge = c("-->", "-->", "-->"),
  to = c("B", "C", "D"),
  nodes = c("A", "B", "C", "D", "E"),
  class = "DAG"
)

# create a non-simple graph
cg4 <- caugi(
  A %-->% B,
  B %-->% A,
  class = "UNKNOWN",
  simple = FALSE
)

cg4@simple # FALSE
#> [1] FALSE
cg4@built # TRUE
#> [1] TRUE
cg4@graph_class # "UNKNOWN"
#> [1] "UNKNOWN"

# create graph, but don't built Rust object yet, which is needed for queries
cg5 <- caugi(
  A %-->% B + C,
  B %-->% D,
  class = "DAG",
  build = FALSE
)

cg5@built # FALSE
#> [1] FALSE
```
